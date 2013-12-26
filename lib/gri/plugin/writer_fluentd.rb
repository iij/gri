require 'gri/writer'
unless Object.const_defined? :MessagePack
require 'gri/mmsgpack'
end

module GRI
  class FluentWriter < Writer
    TYPES['fluent'] = self
    TYPES['fluentd'] = self

    def initialize options={}
      @options = options
      host = options[:fluent_host]
      @sock = TCPSocket.new host, 24224
    end

    def write records
      time = Time.now.to_i
      for record in records
        tag = @options[:fluent_tag] || "gri.#{record['_key']}"
        s = [tag, time, record].to_msgpack
        @sock.write s
      end
    end
  end
end
