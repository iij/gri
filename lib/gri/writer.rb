require 'gri/ltsv'

module GRI
  class Writer
    TYPES = {}

    def self.create wtype, options
      if (klass = TYPES[wtype])
        options.select {|k, v| String === k}.each {|k, v|
          options[k.gsub('-', '_').intern] = v}
        klass.new options
      end
    end

    attr_accessor :loop

    def initialize options={}
    end
  end

  class STDOUTWriter < Writer
    TYPES['stdout'] = self

    def initialize options={}
      @options = options
    end
    def write records
    end
  end

  class RRDWriter < Writer
    TYPES['rrd'] = self

    def initialize options={}
      @options = options
      @gra_dir = options[:gra_dir]
      @sysinfos = {}
    end

    def write records
      now = Time.now.to_i
      hrecords = {}
      updaters = {}
      for record in records
        if (host = record['_host']) and (key = record['_key'])
          if key == 'SYS'
            @sysinfos[host] = record
          else
            data_name, index = key.scan(/\A([^_\d]*)(_?.*)/).first
            basename = "#{host}_#{key}"
            unless (updater = updaters[basename])
              hdir = "#{@gra_dir}/#{host}"
              FileUtils.mkdir_p hdir unless File.directory? hdir
              opts = {:data_name=>data_name, :gra_dir=>@gra_dir,
                :host=>host, :key=>key,
                :interval=>(record['_interval'] || @options[:interval])}
              if @options[:rrdcached_address]
                opts[:rrdcached_address] = @options[:rrdcached_address]
              end
              if @options[:base_dir]
                opts[:base_dir] = @options[:base_dir]
              end
              updater = updaters[basename] = RRDUpdater.new(opts)
            end
            time = (record['_time'] || now).to_i
            updater.update time, record
            key = updater.key
          end
          (r = record.dup)['_key'] = key
          r['_mtime'] = now
          (hrecords[host] ||= {})[key] = r
        end
      end
      hrecords.each {|host, h|
        path = "#{@gra_dir}/#{host}/.records.txt"
        FileUtils.mkdir_p File.dirname(path) unless File.exist? path
        Utils.update_ltsv_file path, '_key', h
      }
      updaters.each {|k, u| u.close}
    end

    def finalize
      unless @sysinfos.empty?
        if @options[:merge_p]
          path = "#{@gra_dir}/.sysdb/sysdb.tmp.#{$$}"
          open(path, 'w') {|f| LTSV.dump_to_io @sysinfos, f}
        else
          path = "#{@gra_dir}/.sysdb/sysdb.txt"
          FileUtils.mkdir_p File.dirname(path) unless File.exist? path
          Utils.update_ltsv_file path, '_host', @sysinfos
        end
      end
    end

    def merge
      sysdb_dir = "#{@gra_dir}/.sysdb"
      path0 = sysdb_dir + '/sysdb.txt'
      values = LTSV.load_from_file(path0) rescue {}
      nvalues = values.inject({}) {|h, v| h[v['_host']] = v; h}
      for path in Dir.glob(sysdb_dir + '/sysdb.tmp.*')
        (other = LTSV.load_from_file(path); File.unlink path) rescue next
        other = other.inject({}) {|h, v| h[v['_host']] = v; h}
        nvalues.merge! other
      end
      LTSV.dump_to_file nvalues, path0
    end
  end

  class TextWriter < Writer
    TYPES['text'] = self
    TYPES['ldb'] = self

    def initialize options={}
      @options = options
      @dir = @options[:tra_dir]
      Dir.mkdir @dir unless File.exist? @dir
    end

    def write records
      now = Time.now
      date = "%04d%02d%02d" % [now.year, now.mon, now.day]
      time = now.to_i
      @ios = {}
      for record in records
        #record['_time'] = time
        if (host = record['_host']) and (key = record['_key'])
          hdir = "#{@dir}/#{host}"
          Dir.mkdir hdir unless File.exist? hdir
          data_name, index = key.scan(/\A([^_\d]*)(_?.*)/).first
          interval = record['_interval']
          kdir = "#{hdir}/#{data_name}_#{interval}"
          Dir.mkdir kdir unless File.exist? kdir
          path = kdir + '/' + date
          unless io = @ios[path]
            io = @ios[path] = File.open(path, 'a')
          end
          io.puts LTSV.serialize(record)
        end
      end
      @ios.each {|k, io| io.close}
    end

    def finalize
    end

    def purge_logs
      if (day = @options[:tra_expire_day].to_i) > 0
        self.class.expire @dir, day
      end
    end

    def self.expire dir, day
      run_expire_path = dir + '/.run_expire'
      now = Time.now
      if File.exist? run_expire_path
        last_run = nil
        open(run_expire_path) {|f| last_run = f.read}
        last_run = Time.at(last_run.to_i)
        return if (now - last_run < 24*3600) and !$debug
      end
      if (day = day.to_i) > 0
        t = (now - day * 24 * 3600)
        expire_date = "%04d%02d%02d" % [t.year, t.mon, t.day]
        begin
          Dir.glob(dir + '/*') {|hdir|
            next if File.symlink? hdir
            Dir.glob(hdir + '/*') {|path|
              if File.directory? path
                Dir.glob(path + '/*') {|path2|
                  if (basename = File.basename path2) < expire_date
                    File.unlink path2
                  end
                }
              end
            }
          }
          open(run_expire_path, 'w') {|f| f.print now.to_i.to_s}
        rescue SystemCallError
          Log.error "ERROR: #{$!}"
        end
      end
    end
  end
end
