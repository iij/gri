require 'gri/config'
require 'gri/scheduler'
require 'gri/collector'
require 'gri/loop'
require 'gri/writer'
require 'gri/q'

module GRI
  class AppCollector
    attr_reader :config, :writers, :metrics

    def initialize config
      @config = config
      @writers = []
      @metrics = Hash.new 0
    end

    def run
      start_time = Time.now
      root_dir = config['root-dir'] ||= Config::ROOT_PATH

      lines = load_target_lines config
      targets = get_targets_from_lines lines, config

      files = Config.getvar 'fake-descr-file'
      fdh = load_fake_descr_files files if files

      if config['updater']
        if (tra_str = config['tra'])
          tra_uri = get_tra_uri tra_str
          TraCollector.tra_uri = tra_uri
          TraCollector.db_class = RemoteLDB
        else
          tra_dir = config['tra-dir'] || root_dir + '/tra'
          TraCollector.tra_dir = tra_dir
          TraCollector.db_class = LocalLDB
        end

        gra_dir = config['gra-dir'] || root_dir + '/gra'
        Dir.mkdir gra_dir unless File.directory? gra_dir
        TraCollector.gra_dir = gra_dir
        scheduler_class = UScheduler
        h = {}
        targets.each {|ary|
          (hostname = ary[1]['hostname'] || ary[1]['alias']) and
            (ary[0] = hostname)
        }
        targets = targets.select {|host, | f = h[host]; h[host] = true; !f}
      else
        scheduler_class = Scheduler
      end

      Log.info "START: pid #{$$}"
      if config['para']
        run_para targets, scheduler_class, start_time.to_i, fdh
      else
        run_single targets, scheduler_class, start_time.to_i, fdh
      end
      for writer in @writers
        if writer.respond_to? :merge
          writer.merge
        end
        if writer.respond_to? :purge_logs
          writer.purge_logs
        end
      end
      Log.info "END: pid #{$$}"
      @metrics['targets'] = targets.size
      @metrics['collector_elapsed'] = Time.now - start_time
    end

    def parse_host_key s
      s.to_s.scan(/\A([-\.A-Za-z0-9]+)_([^_\d]*)(?:_?(.*))/).first
    end

    def load_fake_descr_files files
      h = {}
      for path in files
        if File.exist? path
          open(path) {|f|
            while line = f.gets
              if line =~ /\A([-\.\dA-Za-z]+_\S+)\s+(.*)/
                descr = $2
                host, key = $1.split(/_/, 2)
                (h[host] ||= {})[key] = descr
              end
            end
          }
        end
      end
      h
    end

    def get_tra_uri tra_str
      if tra_str =~ /\A[-\w\.]+(:\d+)\z/
        tra_str = "http://#{tra_str}/"
      elsif tra_str =~ /\A[-\w\.]+\z/
        tra_str = "http://#{tra_str}:7080/"
      end
      uri = URI.parse tra_str rescue nil
    end

    def load_target_lines config
      if config['updater'] and (tra_str = config['tra']) and
          !config['gritab-path']
        tra_uri = get_tra_uri tra_str
        lines = RemoteLDB.get_gritab_lines tra_uri
      else
        root_dir = config['root-dir'] ||= Config::ROOT_PATH
        gritab_path = config['gritab-path'] || root_dir + '/gritab'
        lines = []
        File.open(gritab_path) {|f|
          while line = f.gets
            lines.push line
          end
        }
      end
      lines
    end

    def get_targets_from_lines lines, config
      targets = Config.get_targets_from_lines lines
      goptions = Config.parse_options(*(config.getvar 'option'))
      goptions.merge!(Config.parse_options(*config['O']))
      if config['host-pat']
        hosts_re = config.getvar('host-pat').map {|h| Regexp.new h}
        targets = targets.select {|host, | hosts_re.detect {|re| re === host}}
        #re = Regexp.new config['host-pat']
        #targets = targets.select {|host, options| re === host}
      end
      for host, options in targets
        hoptions = goptions.clone
        hoptions.merge! Config.option_if_match(host, 'option-if-host', config)
        hoptions.merge! options
        options.replace hoptions
      end
      targets
    end

    def run_para targets, scheduler_class, start_time, fdh
    end

    def run_single targets, scheduler_class, start_time, fdh
      loop = Loop.new
      @writers.each {|writer| writer.loop = loop}
      scheduler = scheduler_class.new loop, @metrics
      scheduler.writers = @writers
      scheduler.queue = targets
      scheduler.process_queue
      loop.run
      scheduler.finalize
    end
  end
end
