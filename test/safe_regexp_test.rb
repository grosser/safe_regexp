# frozen_string_literal: true
require_relative "test_helper"
require "benchmark"

SingleCov.covered! uncovered: 14 + (RUBY_VERSION > "2.6.0" ? 0 : 1) # code in fork is not reporting coverage

describe SafeRegexp do
  def simple_match(**options)
    SafeRegexp.execute(/foo/, :=~, "foo", **options).must_equal 0
  end

  def force_timeout(timout = 1)
    regex = /aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?aa?/
    value = "a" * 46
    assert_raises(SafeRegexp::RegexpTimeout) do
      SafeRegexp.execute(regex, :=~, value, timeout: timout)
    end
  end

  def child_processes
    running_processes = `ps -f`.split("\n").map { |line| line.split(/\s+/) }
    running_processes.delete_if { |line| line.last(2) == ["ps", "-f"] } # ignore self
    ppid_index = running_processes.first.index("PPID")
    running_processes.select { |p| p[ppid_index] == Process.pid.to_s }
  end

  def alive?(pid)
    Process.kill 0, pid
    true
  rescue Errno::ESRCH
    false
  end

  after do
    SafeRegexp.shutdown
    maxitest_wait_for_extra_threads
    child_processes.must_equal []
  end

  it "has a VERSION" do
    SafeRegexp::VERSION.must_match /^[\.\da-z]+$/
  end

  describe ".execute" do
    it "can match" do
      simple_match
    end

    it "can match with newlines" do
      SafeRegexp.execute(/\n\n/, :=~, "\n\n").must_equal 0
    end

    it "can transfer MatchData" do
      SafeRegexp.execute(/a/, :match, "a").must_equal ["a"]
    end

    it "is fast" do
      simple_match # warm up
      Benchmark.realtime { simple_match }.must_be :<, 0.01
    end

    it "is threadsafe" do
      t = Thread.new do
        sleep 0.1
        SafeRegexp.execute(/a/, :=~, "a", keepalive: 0)
      end
      force_timeout
      t.value.must_equal 0 # it matched while other was busy
    end

    it "does not leave threads behind" do
      before = Thread.list.size
      10.times do
        simple_match keepalive: 0
        sleep 0.01
      end
      sleep 0.1
      (Thread.list.size - before).must_equal 0
    end

    it "can timeout" do
      time = Benchmark.realtime { force_timeout }
      assert time.between?(0.9, 1.1), time
    end

    it "does not fail when workers parent shuts down" do
      Tempfile.create "safe-regexp-log" do |file|
        Process.wait(fork do
          $stderr.reopen(File.open(file, 'w'))
          simple_match
        end)
        File.read(file).must_equal ""
      end
    end

    it "can configure timeout" do
      time = Benchmark.realtime { force_timeout 0.1 }
      assert time.between?(0, 0.2), time
    end

    it "can run after timeout" do
      2.times { force_timeout 0.1 }
      child_processes.must_equal []
    end

    it "keeps process running to be fast" do
      child_processes.must_equal []
      simple_match
      child_processes.size.must_equal 1
    end

    it "raises exceptions" do
      assert_raises TypeError do
        SafeRegexp.execute /\?\?\?/, :match, 2
      end
      simple_match # works after
    end

    it "shows nice title for forks" do
      simple_match
      child_processes.to_s.must_include "safe_regexp"
    end

    describe "keepalive" do
      it "shuts down after keealive" do
        child_processes.must_equal []
        simple_match keepalive: 0.1
        child_processes.size.must_equal 1
        sleep 0.2
        child_processes.must_equal []
      end

      it "can execute after keepalive death" do
        simple_match keepalive: 0.1
        sleep 0.2
        child_processes.must_equal []
        simple_match
      end

      it "does not loop forever when execution keeps failing" do
        Marshal.expects(:dump).times(2).raises(Errno::EPIPE)
        assert_raises Errno::EPIPE do
          simple_match keepalive: 0.1
        end
      end
    end

    describe "unexpected worker shutdown" do
      # expected input from simple_match inside of fork, cannot be an expect since it is in the fork
      def expect_load_in_fork
        Marshal.stubs(:load).with { Process.pid != parent }.returns([/foo/, :=~, "foo", 1])
      end

      def expect_load_to_fail
        Marshal.expects(:load).with { Process.pid == parent }.raises(EOFError)
      end

      let!(:parent) { Process.pid }
      let!(:first_executor) do
        simple_match
        Thread.current[:safe_regexp_executor].last
      end
      let(:expected_error) { EOFError }

      # retried process kept running, so we need to kill it
      after { Process.kill :KILL, first_executor }

      it "retries" do
        # expected return from reader, first it fails then it has the correct return value
        Marshal.expects(:load).with { Process.pid == parent }.returns(0) # 2nd call
        expect_load_to_fail # 1st call

        expect_load_in_fork

        simple_match
      end

      it "does not retry forever" do
        expect_load_to_fail.times(2)
        expect_load_in_fork
        assert_raises(expected_error) { simple_match }
      end

      it "does not retry when another part raises a similar error" do
        Marshal.expects(:dump).raises(expected_error)
        Marshal.expects(:load).never
        assert_raises(expected_error) { simple_match }
      end

      # not tested, but not important ... tried but ended up super messy/complicated :(
      it "does not retry loading when we just spawned a new process via keepalive error"
    end
  end

  describe ".shutdown" do
    it "kills the executor" do
      simple_match
      pid = Thread.current[:safe_regexp_executor].last
      assert alive?(pid)
      SafeRegexp.shutdown
      refute alive?(pid)
    end

    it "does not crash when ded" do
      2.times { SafeRegexp.shutdown }
    end
  end

  describe ".kill_executor" do
    it "does not blow up when aleady reaped" do
      Process.expects(:kill)
      SafeRegexp.send(:kill_executor, 123)
    end
  end
end
