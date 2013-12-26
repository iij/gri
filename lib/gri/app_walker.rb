module GRI
  class AppWalker
    attr_reader :config, :writers, :metrics

    def initialize config
      @config = config
      @writers = []
      @metrics = Hash.new 0
    end

    def run
      if ARGV.size == 2
        host, sym_oid = ARGV
        snmp = SNMP.new host
        snmp.version = @config['version'] || '1'
        snmp.community = @config['community'] || 'public'
        snmp.walk(sym_oid) {|oid, tag, val|
          p [oid, tag, val]
        }
      end
    end
  end
end
