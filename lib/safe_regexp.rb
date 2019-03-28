# frozen_string_literal: true
require "timeout"

module SafeRegexp
  class SubprocessTimeout < Timeout::Error
  end

  class RegexpTimeout < Timeout::Error
  end

  class << self
    def execute(regex, method, string, timeout: 1, keepalive: 10)
      retried = false
      begin
        read, write, pid = executor
        write.puts Marshal.dump([regex, method, string, keepalive])
      rescue Errno::EPIPE # keepalive killed the process
        raise if retried
        retried = true
        discard_executor
        retry
      end

      begin
        Timeout.timeout(timeout, SubprocessTimeout) { Marshal.load(read.gets) }
      rescue SubprocessTimeout
        kill_executor pid
        raise RegexpTimeout
      end
    end

    def shutdown
      return unless (pid = Thread.current[:safe_regexp_executor]&.last)
      kill_executor pid
    end

    private

    def kill_executor(pid)
      begin
        Process.kill :KILL, pid # kill -9
        begin
          Process.wait pid # reap child
        rescue Errno::ECHILD
          nil # already reaped
        end
      rescue Errno::ESRCH
        nil # already dead
      end
      discard_executor
    end

    # faster than kill if we know it's dead
    def discard_executor
      Thread.current[:safe_regexp_executor] = nil
    end

    # - keepalive gets extended by whatever time the matching takes, but that should not be too bad
    #   we could fix it, but that means extra overhead that I'd rather avoid
    # - using select to avoid having extra threads
    def executor
      Thread.current[:safe_regexp_executor] ||= begin
        in_read, in_write = IO.pipe
        out_read, out_write = IO.pipe
        pid = fork do
          in_write.close
          out_read.close
          keepalive = 1
          loop do
            break unless IO.select([in_read], nil, nil, keepalive)
            break unless (instructions = in_read.gets)
            regexp, method, string, keepalive = Marshal.load(instructions)
            result = regexp.public_send(method, string)
            out_write.puts Marshal.dump(result)
          end
          exit! # to not run any kind of at_exit hook the parent might have configured
        end
        Process.detach(pid)
        in_read.close
        out_write.close
        [out_read, in_write, pid]
      end
    end
  end
end
