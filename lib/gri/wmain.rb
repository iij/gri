require 'optparse'

require 'gri/msnmp'
require 'gri/builtindefs'
require 'gri/vendor'
require 'gri/plugin'

module GRI
  class WMain
    attr_writer :app

    def initialize app=nil
      @app = app
      config_path = ENV['GRI_CONFIG_PATH'] || Config::DEFAULT_PATH
      Config.init config_path
    end

    def run opts=nil
      opts ||= {:server=>'webrick', :Port=>5125}
      optparser = optparse opts
      optparser.parse!
      root_dir = Config['root-dir'] ||= Config::ROOT_PATH
      plugin_dirs = Config.getvar('plugin-dir') || [root_dir + '/plugin']
      Plugin.load_plugins plugin_dirs, Config

      app = @app
      builder = Rack::Builder.new {
        use Rack::Static, :urls=>['/css', '/js'], :root=>app.public_dir
        run app
      }
      if ENV['GATEWAY_INTERFACE']
        Rack::Handler::CGI.run builder
      else
        if Rack.const_defined? :Server
          opts[:app] = builder
          Rack::Server.new(opts).start
        else
          Rack::Handler::WEBrick.run builder, opts
        end
      end
    end

    def optparse opts
      op = OptionParser.new
      op.on('--debug') {$debug = true; STDOUT.sync = true}
      op.on('-d', '--daemonize') {opts[:daemonize] = true}
      op.on('-h', '--host HOST') {|arg| opts[:Host] = arg}
      op.on('-p', '--port PORT', Integer) {|arg| opts[:Port] = arg}
      op.on('-s', '--server SERVER') {|arg| opts[:server] = arg}
      class <<op
        attr_accessor :options
      end
      op.options = opts
      op
    end
  end
end

module Rack
  class Static
    alias :call0 :call
    def call env
      env['PATH_INFO'] ||= '/'
      call0 env
    end
  end
end
