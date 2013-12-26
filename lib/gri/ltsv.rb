# conding: us-ascii

module LTSV
  def escape18 s
    s.to_s.gsub(/\n/, "\\n").gsub(/\r/, "\\r").gsub(/\t/, "\\t")
  end

  def escape19 s
    s.to_s.force_encoding(Encoding::ASCII_8BIT).
      gsub(/\n/, "\\n").gsub(/\r/, "\\r").gsub(/\t/, "\\t")
  end

  alias_method :escape,
    (''.respond_to? :force_encoding) ? :escape19 : :escape18
  extend LTSV

  def serialize value
    h = value.to_hash
    h.map {|k, v| "#{k}:#{escape v}"}.join("\t")
  end

  def dump_to_io values, io
    (Hash === values) and values = values.values
    for value in values
      io.puts serialize(value)
    end
  end

  def dump_to_file values, path
    tmp_path = path + ".tmp#{$$}"
    open(tmp_path, 'w') {|f|
      dump_to_io values, f
    }
    File.rename tmp_path, path
  end

  def parse_string line
    h = {}
    for item in line.split("\t")
      k, v = item.split(':', 2)
      next unless k
      h[k] = case v
             when nil; nil
             when ''; nil
             else v
             end
    end
    h
  end

  def load_from_file path
    File.open(path, 'rb') {|f| parse_io f}
  end

  def parse_io io
    io.map {|line| parse_string line.chomp}
  end
end
