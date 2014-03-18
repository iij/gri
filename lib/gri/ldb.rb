require 'net/http'
require 'gri/ltsv'

module GRI
  class LocalLDB
    def self.get_gritab_lines path
      lines = File.readlines path
    end

    def initialize dir
      @dir = dir
    end

    def get_after data_name, time, pos=0
      open_after(data_name, time) {|t, line, pos|
        h = LTSV.parse_string line
        yield t, h, pos
      }
    end

    def getl_after data_name, time, pos=0
      open_after(data_name, time, pos) {|t, line, pos2|
        yield t, line, pos2
      }
    end

    def open_after data_name, time, pos=0
      ymd = time.strftime '%Y%m%d'
      pat = "#{@dir}/#{data_name}_*/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]"
      for ymd_file in Dir.glob(pat).sort
        vymd = File.basename ymd_file
        if vymd >= ymd
          rtime = Time.local(vymd[0, 4], vymd[4, 2], vymd[6, 2])
          open(ymd_file, 'rb') {|f|
            pos = 0 if f.stat.size < pos
            f.pos = pos
            while line = f.gets
              pos += line.size
              line.chomp!
              tstr = line.scan(/\b_time:(\d+)\b/).first.first rescue nil
              t = Time.at(tstr.to_i)
              if t > time
                yield t, line, pos
              end
            end
            pos = 0
          }
        end
      end
    end

    def get_data_names
      Dir.glob("#{@dir}/*_*").inject({}) {|h, path|
        data_name, interval = File.basename(path).split /_/
        h[data_name || ''] = (interval || 300).to_i
        h
      }
    end

    def close
    end
  end

  class RemoteLDB
    def self.get_gritab_lines tra_uri
      lines = nil
      tra_uri.path = '/gritab'
      get_lines tra_uri
    end

    def self.get_lines uri
      case uri.scheme
      when 'http'
        res = Net::HTTP.get uri
        lines = res.split /\n/
      when 'tra'
        sock = TCPSocket.new(uri.host, uri.port || 7079)
        sock.puts "#{uri.path} #{uri.query}"
        lines = tra_gets sock
        sock.close
      end
      lines
    end

    def self.tra_gets sock
      lines = []
      while line = sock.gets
        line.chomp!
        break if line == '.'
        line.sub!(/\A\./, '')
	lines.push line
      end
      lines
    end

    def initialize tra_uri, host
      @tra_uri = tra_uri
      @host = host
      @sock = nil
    end

    def get_after data_name, time, pos=0
      open_after(data_name, time, pos) {|t, line, pos|
        h = LTSV.parse_string line
        t ||= Time.at(h['_time'].to_i)
        yield t, h, pos
      }
    end

    def open_after data_name, time, pos=0
      case @tra_uri.scheme
      when 'http'
        http = Net::HTTP.new @tra_uri.host, @tra_uri.port
        begin
          url = @tra_uri + "get?h=#{@host}&s=#{data_name}&t=#{time.to_i}"
          res = http.get url.request_uri
          res.body.each_line {|line| yield nil, line.chomp, pos}
        end while(time = res['x-gri-continue'])
        http.finish
      when 'tra'
        sock = sock_connect @tra_uri.host, @tra_uri.port
        begin
          query = "h=#{@host}&s=#{data_name}&t=#{time.to_i}&pos=#{pos}"
          sock.puts "/get #{query}"
          lines = self.class.tra_gets sock
          ind = lines.index ''
          headers = lines.slice!(0, ind+1)
          if headers.detect {|line| line =~ /x-gri-pos: (\d+)/i}
            pos = $1.to_i
          end
          lines.each {|line| yield nil, line, pos}
          if headers.detect {|line| line =~ /x-gri-continue: (\d+) (\d+)/i}
            time = $1.to_i
            pos = $2.to_i
          else
            time = nil
          end
        end while time
      end
    end

    def sock_connect host, port
      @sock ||= TCPSocket.new host, port
    end

    def close
      @sock.close rescue nil
    end

    def get_data_names
      @tra_uri.path = '/get_data_names'
      @tra_uri.query = "h=#{@host}"
      lines = self.class.get_lines @tra_uri
      lines.inject({}) {|h, line|
        data_name, interval = line.split /_/
        h[data_name || ''] = (interval || 300).to_i
        h
      }
    end
  end
end
