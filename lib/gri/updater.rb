require 'fileutils'

require 'gri/builtindefs'
require 'gri/rrd'
require 'gri/utils'
require 'gri/config'

module GRI
  class Updater
    include Utils
    attr_reader :options

    def self.get_tag_ary description
      unless @tag_pats
        @tag_pats = (pats = GRI::Config.getvar 'tag-rule') ?
        pats.map {|patline| pat, *remain =
            patline.scan(/^\/([^\/]+)\/\s+(\S+)\s+(\S+)\s+(\S+)/)[0] #/
          [Regexp.new(pat), *remain]} : []
      end
      @tag_pats.map {|re, group, subdir, descr_v|
        if re === description
          m = $~.to_a
          if group =~ /^\$(\d+)(\.\w+)?/
            group = m[$1.to_i].dup
            group.downcase! if $2 == '.downcase'
          end
          if subdir =~ /^\$(\d+)(\.\w+)?/
            subdir = m[$1.to_i].dup
            subdir.downcase! if $2 == '.downcase'
          end
          if descr_v =~ /^\$(\d+)/
            descr_v = m[$1.to_i]
          end
          [group, subdir, descr_v]
        else
          nil
        end
      }.compact
    end

    def initialize options={}
      @options = options
      @interval = options[:step] || options[:interval] || 300
      @config = GRI::Config
    end

    def update time, record
    end
  end

  class RRDUpdater < Updater
    attr_reader :rrd, :key
    attr_accessor :rrd_class

    def initialize options={}
      super
      @tagrrds = {}
    end

    def create_rrd path, time, interval, ds_specs, rra_specs
      ds_args, @record_keys = mk_ds_args ds_specs, interval
      rra_args = rra_specs || mk_rra_args
      @rrd_args = ds_args + rra_args
      rrd = (@rrd_class || RRD).new @options[:rrdcached_address],
        @options[:base_dir]
      rrd.set_create_args path, (time - interval), interval, *@rrd_args
      rrd
    end

    def mk_ds_args ds_specs, interval
      ds_args = []
      record_keys = []
      n = 0
      for spec_line in ds_specs
        key, dsname, dst = spec_line.split /,/
        heartbeat = interval * ((dst == 'DERIVE' or dst == 'COUNTER') ? 2.5 : 2)
        key = key[1..-1].intern if key[0] == ?:
        record_keys.push key
        ds_args.push "DS:#{dsname}:#{dst}:#{heartbeat.to_i}:U:U"
        n += 1
      end
      return ds_args, record_keys
    end

    def mk_rra_args
      rra_args = []
      for cf in ['average', 'max', 'min']
        optrraname = "rra-#{@options[:data_name]}-#{cf}"
        if (optrra = @config.getvar optrraname)
          for line in optrra
            steps, rows = line.split
            rra_args.push "RRA:#{cf.upcase}:0.5:#{steps}:#{rows}"
          end
        else
          optrraname = 'rra-' + cf
          optrra = @config.getvar optrraname
          if optrra
            for line in optrra
              steps, rows = line.split
              rra_args.push "RRA:#{cf.upcase}:0.5:#{steps}:#{rows}"
            end
          end
        end
      end
      rra_args.size.zero? ? default_rra_args : rra_args
    end

    def default_rra_args
      ['RRA:AVERAGE:0.5:12:9000', 'RRA:MAX:0.5:1:20000',
        'RRA:MAX:0.5:12:9000', 'RRA:MAX:0.5:144:2000']
    end

    def mk_key options
      unless (key = options[:key])
        data_name = options[:data_name]
        key = (Numeric === (index = options[:index])) ?
        "#{data_name}#{index}" : "#{data_name}_#{index}"
      end
      key
    end

    def mk_path options
      host = options[:host]
      dir = options[:dir] || options[:gra_dir] + '/' + host
      dkey = mk_key options
      "#{dir}/#{host}_#{dkey}.rrd"
    end

    def update time, record
      unless @rrd
        data_name = options[:data_name]
        @specs = DEFS.get_specs data_name
        return unless @specs # unknown data_name
        return unless @specs[:ds]
        #if (index_key = (@specs[:index_key] || @specs[:named_index]) and
        #    index = record[index_key])
        #  options[:index] = key_encode index
        #  options.delete :key
        #end
        @key = mk_key options
        return if (ex_proc = @specs[:exclude?]) and ex_proc.call(record)
        path = mk_path options
        ds_specs = @specs[:ds]
        return if !ds_specs or ds_specs.empty?
        @rrd = create_rrd path, time, (@interval || 300),
          ds_specs, @specs[:rra]
      end
      data = @record_keys.map {|key| record[key]}
      s = "#{time.to_i}:#{mk_update_str data}"
      puts "  update #{@key} #{s}" if record['_d']
      @rrd.buffered_update s

      if (prop = @specs[:prop]) and (descr_k = prop[:description]) and
          (description = record[descr_k]) and !description.empty?
        for group, subdir, descr_v in Updater.get_tag_ary(description)
          unless (tagrrd = @tagrrds[group + '/' + subdir])
            tagrrd = create_tagrrd group, subdir, descr_v, record
            @tagrrds[group + '/' + subdir] = tagrrd
          end
          tagrrd.buffered_update s
        end
      end
    end

    def mk_update_str data
      data.map {|item|
        if item =~ /\A0x[\da-f]+\z/i
          Integer(item)
        elsif item == '' or item == nil or
            (item.kind_of?(Float) and not(item.finite?)) or
            (item.kind_of?(String) and item !~ /\A[-+e\.\d]+$/i)
          'U'
        else
          item
        end
      }.join(':')
    end

    def create_tagrrd group, subdir, descr_v, record
      grp_dir = "#{options[:gra_dir]}/#{group}"
      Dir.mkdir grp_dir unless File.exist? grp_dir
      tag_dir = "#{grp_dir}/#{subdir}"
      Dir.mkdir tag_dir unless File.exist? tag_dir
      open(tag_dir + '/.description', 'w') {|f| f.puts descr_v}

      time = record['_time']
      path = "#{tag_dir}/#{@options[:host]}_#{@key}.rrd"
      tagrrd = (@rrd_class ||RRD).new @options[:rrdcached_address],
        @options[:base_dir]
      tagrrd.set_create_args path, (time - @interval), @interval, *@rrd_args
      tagrrd
    end

    def close
      if @rrd
        @rrd.flush_buffer
      end
      @tagrrds.each_value {|tagrrd| tagrrd.flush_buffer}
    end
  end
end
