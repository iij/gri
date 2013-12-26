require 'gri/collector'
require 'gri/ldb'

module GRI
  class TraCollector < Collector
    TYPES['tra'] = self

    def on_attach
      # @loop.detach self if @config['nop']
      dir = "#{self.class.gra_dir}/#{host}"
      Dir.mkdir dir unless File.directory? dir

      db_class = self.class.db_class
      db = (db_class <= RemoteLDB) ? db_class.new(self.class.tra_uri, host) :
        db_class.new("#{self.class.tra_dir}/#{host}")

      @loop.next_tick {
        begin
          update_rrd_dir dir, db, options
        ensure
          @loop.detach self
          db.close
        end
      }
    end

    def update_rrd_dir dir, db, options
      data_names = db.get_data_names
      for data_name, interval in data_names
        lu_path = "#{dir}/.lu_#{data_name}"
        lu_time = nil
        lu_pos = nil
        if File.exist? lu_path
          str = File.read(lu_path)
          if str =~ /\A(\d+) (\d+)\Z/
            lu_time = Time.at $1.to_i
            lu_pos = $2.to_i
          end
        end
        lu_time ||= Time.at(0)
        lu_pos ||= 0

        update_p = false
        t = nil
        records = []
        db.get_after(data_name, lu_time, lu_pos) {|t, record, pos|
          if $debug
            ts = t.strftime '%Y-%m-%d %H:%M:%S'
            puts "update #{ts} #{record['_host']} #{record['_key']}"
          end
          record['_interval'] = interval
          records.push record
          update_p = true
          lu_time = t
          lu_pos = pos
          if records.size > 2000
            @cb.call records
            records.clear
          end
        }
        if update_p
          @cb.call records
          open(lu_path, 'w') {|f| f.print "#{lu_time.to_i} #{lu_pos}"}
        end
      end
    end

    def recdump dir, records
      path = dir + '/.rdump'
      open(path, 'a') {|f|
        records.each {|r| f.puts r.inspect}
      }
    end

    class <<self
      attr_accessor :tra_dir, :gra_dir
      attr_accessor :db_class, :tra_uri
    end
  end
end
