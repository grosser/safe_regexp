# frozen_string_literal: true
require_relative "test_helper"
require "benchmark"

SingleCov.covered! uncovered: 9 # code in fork is not reporting coverage

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
end
