if Object.const_defined? :RUBY_VERSION

require 'open3'
require 'gri/collector'

module GRI
  class ExecCollector < Collector
    TYPES['exec'] = self
    MAX_INPUT_SIZE = 8192

    def sync?; false; end

    def on_init
      @rbuf = ''
      case options['separator']
      when 'tab'
        @sep = /\t/
      when /^[!"%&,->@-Z_-z]+/
        @sep = Regexp.new options['separator']
      else
        @sep = nil
      end
      if options['out_keys']
        @out_keys = options['out_keys'].split(/\s*,\s*/)
      end
      @transpose = !!options['transpose']
    end

    def on_attach
      cmd = options['cmd']
      stdin, stdout, stderr, wait_thr = popen cmd
      stdin.close
      loop.watch stdout, :r, 0, self
      loop.watch stderr, :r, 0, self
    end

    def popen cmd
      Open3.popen3 cmd
    end

    def on_readable io=nil
      begin
        while data = io.read_nonblock(MAX_INPUT_SIZE)
          on_read data
        end
      rescue Errno::EAGAIN, Errno::EINTR
        loop.watch io, :r, 0, self
      rescue SystemCallError, EOFError, IOError, SocketError
        on_close
      end
    end

    def on_read data
      @rbuf << data
      records = []
      while true
        break unless @rbuf =~ /\n/
        line, rbuf = @rbuf.split /^/, 2
        @rbuf.replace(rbuf || '')
        line.chomp!
        record = values2record line.split(@sep)
        if @transpose
          records += record.inject([]) {|a, kv|
            a.push({'_host'=>host, '_key'=>"num_#{kv.first}", 'num'=>kv.last})
            a
          }
        else
          record['_host'] = host
          records.push record
        end
      end
      @cb.call records unless records.empty?
    end

    def values2record values
      h = {}
      values.each_with_index {|v, i|
        h[@out_keys[i]] = v if @out_keys[i]
      }
      h
    end

    def on_close
      loop.detach self
    end
  end
end

end
