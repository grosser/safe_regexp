# frozen_string_literal: true

module SafeRegexp
  RESCUED_EXCEPTION = StandardError

  class RegexpTimeout < Timeout::Error
  end

  class << self
    def execute(regex, method, string, timeout: 1, keepalive: 10)
      retried = false

      begin
        loading_result = false

        begin
          read, write, pid = executor
          Marshal.dump([regex, method, string, keepalive], write)
        rescue Errno::EPIPE
          # keepalive already killed the process, but we don't check before sending
          # since that would be a race condition and cause overhead for the 99.9% case
          raise if retried
          retried = true
          discard_executor # avoiding kill overhead since it's already dead
          retry # new executor will be created by `executor` call
        end

        unless IO.select([read], nil, nil, timeout)
          kill_executor pid
          raise RegexpTimeout
        end

        loading_result = true
        result = Marshal.load(read)
      rescue EOFError # process was dead from keepalive when we sent to it or got killed from outside
        raise if retried || !loading_result
        retried = true
        discard_executor # avoiding kill overhead since it's already dead
        retry
      end

      result.is_a?(RESCUED_EXCEPTION) ? raise(result) : result
    end

    def shutdown
      return unless (pid = Thread.current[:safe_regexp_executor]&.last)
      kill_executor pid
    end

    private

    def kill_executor(pid)
      begin
        Process.kill :KILL, pid # kill -9
      rescue Errno::ESRCH
        nil # already dead
      else
        begin
          Process.wait pid # reap child
        rescue Errno::ECHILD
          nil # already reaped
        end
      end
      discard_executor
    end

    # faster than kill if we know it's dead
    def discard_executor
      Thread.current[:safe_regexp_executor] = nil
    end

    # - keepalive gets extended by whatever time the matching takes, but that should not be too bad
    #   we could fix it, but that means extra overhead that I'd rather avoid
    # - using select to avoid having extra threads / Timeout
    def executor
      Thread.current[:safe_regexp_executor] ||= begin
        in_read, in_write = IO.pipe
        out_read, out_write = IO.pipe
        pid = fork do
          in_write.close
          out_read.close
          keepalive = 1 # initial payload should come in shortly after boot
          loop do
            break unless IO.select([in_read], nil, nil, keepalive)
            begin
              regexp, method, string, keepalive = Marshal.load(in_read)
            rescue EOFError # someone killed this fork
              break
            end
            begin
              result = regexp.public_send(method, string)
              result = result.to_a if result.is_a?(MatchData) # cannot be dumped
            rescue RESCUED_EXCEPTION
              result = $!
            end
            Marshal.dump(result, out_write)
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
