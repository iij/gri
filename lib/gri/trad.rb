require 'gri/ldb'

module GRI
  class Trad
    def initialize
      @acls = nil
      @tra_dir = nil
    end

    def public_dir
      '/notexist'
    end

    def load_acls config
      acls = config.getvar 'acl-permit'
      acls = acls ? acls.map {|pat| Regexp.new pat} : []
      acls.push(/^127\.0\.0\.1$/)
      acls.push(/^::ffff:127\.0\.0\.1$/)
      acls.push(/^::1$/)
      puts "acls: #{acls.join(',')}" if $debug
      acls
    end

    def allowed? acls, remote_addr
      acls.detect {|re| remote_addr =~ re}
    end

    def call env
      @acls ||= load_acls Config
      unless allowed?(@acls, env['REMOTE_ADDR'])
        return [401, {}, ['Unauthorized']]
      end

      @root_dir ||= Config['root-dir'] || Config::ROOT_PATH
      @tra_dir ||= (Config['tra-dir'] || @root_dir + '/tra')

      req = Rack::Request.new env
      serve @tra_dir, req.path_info, req
    end

    def serve tra_dir, path_info, params
      headers = {}
      body = []

      if path_info =~ /\A\/get\b/ #/
        s = params['s']
        dir = "#{tra_dir}/#{params['h']}"
        if File.directory?(dir)
          t = Time.at(params['t'].to_i)
          pos = params['pos'].to_i
          ldb = LocalLDB.new dir
          headers.clear
          prev_time = 0
          ldb.getl_after(s, t, pos) {|time, line, pos|
            if body.size > 1000 and time.to_i > prev_time
              headers['X-GRI-Continue'] = "#{prev_time.to_s} #{pos}"
              break
            end
            prev_time = time.to_i
            body.push(line+"\n")
          }
          headers['X-GRI-Pos'] = pos.to_s
        end
      elsif path_info =~ /\A\/get_data_names\b/ #/
        dir = "#{tra_dir}/#{params['h']}"
        ldb = LocalLDB.new dir
        ldb.get_data_names.each {|k, v| body.push "#{k}_#{v}\n"}
      elsif path_info =~ /\A\/gritab\b/ #/
        gritab_path = Config['gritab-path'] || @root_dir + '/gritab'
        if File.exist? gritab_path
          open(gritab_path) {|f|
            while line = f.gets
              next if line =~ /\A\s*#|\A\z/
              body.push line
            end
          }
        end
      end
      [200, headers, body]
    end

    def run options={}
      status = :init
      optparser = optparse options
      optparser.parse!
      Process.daemon true if options[:daemonize] and !$debug
      config_path = options[:config_path] || GRI::Config::DEFAULT_PATH
      config = GRI::Config.init config_path
      @acls ||= load_acls config
      @root_dir ||= config['root-dir'] || GRI::Config::ROOT_PATH
      @tra_dir ||= (config['tra-dir'] || @root_dir + '/tra')
      log_dir = config['log-dir'] || @root_dir + '/log'
      Dir.mkdir log_dir unless File.exist? log_dir
      Log.init "#{log_dir}/#{optparser.program_name}.log"

      Signal.trap(:USR1){
        Log.info "reloading acls"
        config = GRI::Config.init config_path
        @acls = load_acls config
      }

      Signal.trap(:WINCH){
        Log.info "going to shutdown"
        status = :shutdown
      }

      bind_address = options[:bind_address] || '0.0.0.0'
      port = options[:port] || 7079
      server_sock = TCPServer.new bind_address, port
      rs0 = [server_sock]
      params = {}
      status = :start
      while true and status != :stop
        if status == :shutdown and rs0.size == 1 and rs0[0].kind_of?(TCPServer)
          Log.info "shutting down"
          server_sock.close
          status = :stop
          next
        end
        next unless (a = IO.select(rs0, nil, nil, 1))
        rs, = a
        for io in rs
          begin
            if io.kind_of? TCPServer
              sock = server_sock.accept
              peername = sock.peeraddr[2]
              peeraddr = sock.peeraddr[3]
              if status == :shutdown
                sock.close
                Log.info "#{peeraddr}: reject due to shutting down"
                next
              elsif allowed?(@acls, peeraddr)
                puts "#{peeraddr}: accespt #{sock.object_id}" if $debug
              else
                sock.close
                puts "#{peeraddr}: reject" if $debug
                next
              end
              rs0.push sock
            elsif io.eof?
              io.close
              rs0.delete io
            else
              line = io.gets
              line.chomp!
              if line =~ /\A(\/\w+)\s*(\S+)?$/ #/
                pi = $1
                qs = $2
                params.clear
                (qs || '').split(/[&;] */n).each {|item|
                  k, v = item.split('=', 2)
                  params[k] = v
                }
                puts "#{io.object_id}: serve #{pi} #{params.inspect}" if $debug
                code, h, body = serve @tra_dir, pi, params
                h.each {|k, v| io.puts "#{k}: #{v}"}
                io.puts
                body.each {|l|
                  if l =~ /\A\./
                    io.puts ".#{l}"
                  else
                    io.puts l
                  end
                }
                io.puts "."
              end
            end
          rescue Exception
            Log.error "ERROR: #{$!}: #{$@.inspect}"
          end
        end
      end

      Log.info "stopped"
      exit 0
    end

    def optparse opts
      op = OptionParser.new
      op.on('--debug') {$debug = true; STDOUT.sync = true}
      op.on('-c', '--config-path=PATH') {|arg| opts[:config_path] = arg}
      op.on('-d', '--daemonize') {opts[:daemonize] = true}
      op.on('-b', '--bind-address=ADDRESS') {|arg| opts[:bind_address] = arg}
      op.on('-p', '--port=PORT', Integer) {|arg| opts[:port] = arg}
    end

    if __FILE__ == $0
      require 'socket'
      require 'optparse'
      require 'gri/q'
      require 'gri/config'
      require 'gri/log'
      require 'gri/util_daemon'
      new.run
    end
  end
end
