module GRI
  class Loop
    attr_reader :collectors

    def initialize
      @collectors = {}

      @rs = []
      @ws = []
      @handlers = {}
      @times = {}
      @tos = {}
      @pt = Time.now
      @procs = []
    end

    def attach collector
      @collectors[collector] = true
      collector.attach self
    end

    def detach collector
      collector.on_detach
      @collectors.delete collector
      del_ios = @handlers.select {|k, v| v == collector}
      del_ios.each {|io, handler|
        @handlers.delete io
        @times.delete io
        @tos.delete io
        @rs.delete io
        @ws.delete io
      }
      @on_detach.call
    end

    def on_detach &on_detach
      @on_detach = on_detach
    end

    def next_tick &cb
      @procs.push cb
    end

    def watch io, flag, to, handler
      now = Time.now
      @handlers[io] = handler
      @times[io] = now
      @tos[io] = to
      case flag
      when :r
        @rs.push io
      when :w
        @ws.push io
      when :rw
        @rs.push io
        @ws.push io
      end
    end

    def has_active_watchers?
      !(@rs.empty? and @ws.empty? and @collectors.empty? and @procs.empty?)
    end

    def run
      while has_active_watchers?
        run_once
      end
    end

    def run_once
      while (cb = @procs.shift)
        cb.call
      end
      if (a = IO.select(@rs, @ws, nil, 1))
        rs, ws = a
        for io in rs
          @rs.delete io
          if (h = @handlers[io])
            h.on_readable io
          end
        end
        for io in ws
          @ws.delete io
          if (h = @handlers[io])
            h.on_writable io
          end
        end
      end
      if @pt.sec != (now = Time.now).sec
        for io in @rs + @ws
          if (t = @times[io]) and (to = @tos[io]) > 0 and (now - t >= to)
            @rs.delete io
            @ws.delete io
            if (h = @handlers[io])
              h.retry
            end
          end
        end
        for c in @collectors.keys
          if c.attached_at and c.attached_at + c.timeout < now
            c.on_timeout
            detach c
          end
        end
        @pt = now
      end
    end
  end
end
