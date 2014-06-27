require 'gri/writer'
require 'gri/utils'
require 'influxdb'

module GRI
  class InfluxdbWriter < Writer
    TYPES['influxdb'] = self

    include Utils

    def initialize options={}
      @options = options
      database = 'gri'
      host = options[:influxdb_host] || 'localhost'
      username = options[:influxdb_username] || 'root'
      password = options[:influxdb_password] || 'root'

      @db = InfluxDB::Client.new database, :host=>host,
        :username=>username, :password=>password,
        :time_precision=>'s'
      dbs = @db.get_database_list
      if (dbs.select {|h| h['name'] == 'gri'}).empty?
        Log.info 'InfluxDB: create database'
        @db.create_database 'gri'
      end
      @buf = {}
    end

    def write records
      time = Time.now.to_i
      for record in records
        record = record.dup
        time = record.delete '_time'
        #host = record.delete '_host'
        key = record.delete '_key'
        record.delete '_mtime'
        record.delete '_interval'
        data_name, index = parse_key key
        next if data_name == 'SYS'
        if data_name == ''
          data_name = 'interfaces'
        elsif data_name == 'docker'
          data_name = "docker.#{index}"
        end
        record.update :time=>time.to_i, :key=>index
        buffered_write data_name, record
      end
    end

    def buffered_write data_name, record
      (ary = (@buf[data_name] ||= [])).push record
      if ary.size > 1000
        flush data_name, ary
      end
    end

    def flush data_name, ary
      while (sa = ary.take 10000; ary[0, 10000] = []; !sa.empty?)
        @db.write_point data_name, sa
      end
    end

    def finalize
      for data_name, ary in @buf
        flush data_name, ary
      end
    end
  end
end
