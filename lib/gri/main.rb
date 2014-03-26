require 'optparse'
require 'socket'

require 'rubygems'

require 'gri/config'
require 'gri/builtindefs'
require 'gri/plugin'
require 'gri/app_collector'
require 'gri/pcollector'
require 'gri/tra_collector'
require 'gri/updater'
require 'gri/writer'
require 'gri/log'

module GRI
  class Main
    attr_reader :config, :options

    def initialize
      @options = {}
      optparser = optparse @options
      optparser.parse!
      config_path = options[:config_path] || GRI::Config::DEFAULT_PATH
      @config = GRI::Config.init config_path
      @options.each {|k, v| @config.setvar k.to_s, v}
      root_dir = @config['root-dir'] ||= Config::ROOT_PATH

      plugin_dirs = @config.getvar('plugin-dir') || [root_dir + '/plugin']
      GRI::Plugin.load_plugins plugin_dirs, @config

      log_dir = @config['log-dir'] || root_dir + '/log'
      Dir.mkdir log_dir unless File.exist? log_dir
      Log.init "#{log_dir}/#{optparser.program_name}.log",
        :log_level=>@config['log-level']

      @config['tra-dir'] ||= root_dir + '/tra'
      @config['gra-dir'] ||= root_dir + '/gra'
    end

    def run
      @config['para'] = true unless config.has_key? 'para'
      if @config['walker']
        app = AppWalker.new @config
        writer = Writer.create 'stdout', @config.to_h
        app.writers.push writer
      elsif @config['collector']
        # collector
        app = AppCollector.new @config
        writer = Writer.create 'ldb', @config.to_h
        app.writers.push writer
      else
        # minigri
        app = AppCollector.new @config
        wopts = @config.to_h.update :merge_p=>true
        writer = Writer.create 'rrd', wopts
        app.writers.push writer
      end
      if @options['writers']
        for w in @options['writers']
          writer = Writer.create w, @config.to_h
          app.writers.push writer if writer
        end
      end
      app.run
      if app.metrics[:nometrics].zero? and !$debug
        hostname = Socket.gethostname rescue 'unknown'
        hostname = hostname.split(/\./).first
        t = Time.now.to_i
        interval = @config['interval'] || 300
        records = app.metrics.map {|k, v|
          {'_interval'=>interval, '_host'=>"GRIMETRICS-#{hostname}",
            '_time'=>t, '_key'=>"num_#{k}", 'num'=>v}}
        writer = Writer.create 'ldb', @config.to_h
        writer.write records
      end
    end

    def optparse opts
      op = OptionParser.new
      op.on('--debug') {$debug = true; STDOUT.sync = true;
        opts['log-level'] = 'debug'}
      op.on('--Doption=STR') {|arg| (opts['Doption'] ||= []).push arg}

      op.on('--add-writer=WRITER') {|arg| (opts['writers'] ||= []).push arg}
      op.on('-O OPT_STR') {|arg| (opts['O'] ||= []).push arg}
      op.on('--collector') {opts['collector'] = true}
      op.on('--config-path=PATH') {|arg| opts[:config_path] = arg}
      op.on('--duration=SEC', Integer) {|arg| opts['duration'] = arg}
      op.on('--fake-snmp=FILE') {|arg| opts['fake_snmp'] = arg}
      op.on('--gritab-path=PATH') {|arg| opts['gritab-path'] = arg}
      op.on('--host-pat=PAT', '-h') {|arg| (opts['host-pat'] ||= []).push arg}
      op.on('--interval=SEC', Integer) {|arg| opts['interval'] = arg}
      op.on('--log-level=LEVEL') {|arg| opts['log-level'] = arg}
      op.on('--nop') {opts['nop'] = true}
      op.on('--para') {opts['para'] = true}
      op.on('-p', '--plugin-dir=DIR') {|arg|
        (opts['plugin-dir'] ||= []).push arg}
      op.on('--rrdupdater', '--updater') {opts['updater'] = true}
      op.on('--single') {opts['para'] = false}
      op.on('--tra=URL') {|arg| opts['tra'] = arg}

      op.on('-c COMMUNITY') {|arg| opts['community'] = arg}
      op.on('-v VER') {|arg| opts['version'] = arg}
      op
    end
  end
end
