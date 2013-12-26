require 'gri/ltsv'

module GRI
  module Utils
    module_function

    def load_records dir
      values = LTSV.load_from_file dir + '/.records.txt'
      values.inject({}) {|h, v| h[v['_key']] = v; h}
    end

    def search_records dirs, host
      for dir in dirs
        path = "#{dir}/#{host}/.records.txt"
        if File.exist? path
          values = LTSV.load_from_file path
          rh = values.inject({}) {|h, v| (k = v['_key']) and h[k] = v; h}
          return [dir, rh]
        end
      end
      nil
    end

    def get_prop record
      h = {}
      data_name, index = parse_key record['_key']
      record['_index'] = index
      if data_name and (specs = DEFS.get_specs data_name) and specs[:prop]
        specs[:prop].each {|k1, k2| h[k1] = record[k2] if record[k2]}
        h[:name] ||= specs[:prop][:name]
      end
      h
    end

    def update_ltsv_file path, key, other
      if File.exist? path
        values = LTSV.load_from_file path
        nvalues = values.inject({}) {|h, v| h[v[key]] = v; h}
        nvalues.merge! other
      else
        nvalues = other
      end
      LTSV.dump_to_file nvalues, path
    end

    def parse_key s
      s.to_s.scan(/\A([^_\d]*)(?:_?(.*))/).first
    end

    def parse_host_key s
      s.to_s.scan(/\A([-\.A-Za-z0-9]+)_([^_\d]*)(?:_?(.*))/).first
    end

    def url_encode(s)
      s.to_s.gsub(/[^a-zA-Z0-9_\-.]/n){ sprintf("%%%02X", $&.unpack("C")[0]) }
    end

    def key_encode s
      s.to_s.tr(':/ =', '\-\-__').gsub(/[^-a-zA-Z0-9_.]/n) { #/
        "%02X"%$&.unpack('C').first}
    end
  end
end
