require 'optparse'
require 'uri'
require 'open-uri'
require 'yaml'

require 'gri/q'
require 'gri/gparams'
require 'gri/sgraph'

module GRI
  class Spark
    def run options={}
      optparser = optparse options
      optparser.parse!
      exit unless (url_s = ARGV.shift)

      url = URI.parse url_s
      params = GParams.new
      parse_query url.query, params
      fix_params params, options
      url.query = mk_query params
      if options[:user]
        if options[:pass]
          http_basic_authentication = [options[:user], options[:pass]]
        else
          print "Password:"
          system "stty -echo"
          password = $stdin.gets.chop
          system "stty echo"
          http_basic_authentication = [options[:user], password]
        end
      end
      obj = fetch url, http_basic_authentication
      graph = Sgraph.new options
      graph.render obj, {}, url
    end

    def fix_params params, options
      etime = params['etime'].to_i
      etime = (Time.now + etime).to_i if etime <= 0
      if (t = options[:t]) and (v = Sgraph::TERMS[t])
        stime = (stime = params['stime']) ? stime.to_i : -v[1]
        stime = (etime + stime).to_i if stime <= 0
      else
        stime = (stime = params['stime']) ? stime.to_i : -28*3600
        stime = (etime + stime).to_i if stime <= 0
      end
      params['stime'] = stime
      params['etime'] = etime
      params['maxrows'] = 70
      params['fmt'] = 'json'
    end

    def fetch url, http_basic_authentication
      if http_basic_authentication
        str = open(url,
                   :http_basic_authentication=>http_basic_authentication).read
      else
        str = open(url).read
      end
      obj = YAML.load str
      obj
    end

    def mk_query params
      params.map {|k, v|
        (Array === v) ? v.map {|vv| "#{k}=#{vv}"} : "#{k}=#{v}"
      }.flatten.join('&')
    end

    def parse_query qs, params={}
      (qs || '').split(/[&;] */n).each {|item|
        k, v = item.split('=', 2)
        params[k] = v
      }
      params
    end

    def optparse opts
      op = OptionParser.new
      op.on('--debug') {$debug = true; STDOUT.sync = true;
        opts['log-level'] = 'debug'}
      op.on('--Doption=STR') {|arg| (opts['Doption'] ||= []).push arg}
      op.on('-O OPT_STR') {|arg| (opts['O'] ||= []).push arg}
      op.on('-c', '--config-path=PATH') {|arg| opts[:config_path] = arg}
      op.on('--log-level=LEVEL') {|arg| opts['log-level'] = arg}
      op.on('--nop') {opts['nop'] = true}
      op.on('-t ARG') {|arg| opts[:t] = arg}
      op.on('-u', '--user=USER') {|arg| opts[:user] = arg}
      op.on('-p', '--password=PASSWORD') {|arg| opts[:pass] = arg}
      op
    end
  end
end
