#require 'gri/utils'
require 'gri/msnmp'
require 'gri/builtindefs'
require 'gri/vendor'
require 'gri/polling_unit'

module GRI
  class Collector
    TYPES = {}

    attr_reader :host, :options
    attr_reader :loop, :attached_at
    attr_accessor :interval, :timeout

    def self.create col_type, host, options, fake_descr_hash={}, &cb
      if (klass = TYPES[col_type])
        klass.new host, options, fake_descr_hash, &cb
      end
    end

    def initialize host, options, fake_descr_hash, &cb
      @host = host
      @options = options
      @cname = @options['cname']
      @hostname = @options['hostname'] || @options['alias']
      @fake_descr_hash = fake_descr_hash || {}
      @cb = cb
      @buffers = []
      @results = []
      @on_error = nil
      @on_retry = nil
      on_init
    end

    def sync?; true; end

    def on_init
    end

    def attach loop
      @loop = loop
      on_attach
    end

    def on_attach
    end

    def on_detach
    end

    def on_timeout
    end

    def on_error &block
      @on_error = block
    end

    def on_retry &block
      @on_retry = block
    end
  end

  class SNMPCollector < Collector
    TYPES['snmp'] = self
    SYSOIDS = BER.enc_oid_list(['sysDescr', 'sysName', 'sysObjectID',
                                 'sysUpTime', 'sysLocation'].map {|n|
                                 oid = SNMP::OIDS[n] + '.0'
                                 SNMP.add_oid n + '.0', oid
                                 oid})

    def sync?; false; end

    def on_attach
      now = Time.now
      now_i = now.to_i
      @attached_at = now
      @results.clear
      @tout = 5
      @preq = nil
      @snmp = SNMP.new(@cname || @host, options['port'])
      if options['fake-snmp']
        require 'gri/fake_snmp'
        @snmp = FakeSNMP.new options['fake-snmp']
      else
        @snmp.version = options['ver'] if options['ver']
        @snmp.community = options['community'] if options['community']
      end

      varbind = SYSOIDS
      get(varbind) {|results|
        sysinfo = {'_host'=>(@hostname || host),
          '_key'=>'SYS', '_time'=>now_i, '_mtime'=>now_i}
        results.each {|enoid, tag, val|
          (k = SNMP::ROIDS[enoid]) and sysinfo[k.sub(/\.0$/, '')] = val
        }
        sysinfo['sysDescr'] and sysinfo['sysDescr'].gsub!("\n", ' ')

        vendor = Vendor.check sysinfo, options
        if $debug
          puts "snmp: #{host} (#{vendor.name}): #{sysinfo['sysDescr']}"
          puts vendor.options.inspect
        end

        @snmp.version = vendor.options['ver'] if vendor.options['ver']
        punits = vendor.get_punits
        punits_d = punits.dup
        @workhash = punits.inject({}) {|h, pu| h[pu.cat] = {}; h}
        poll1(punits) {
          if !options.has_key?('SYS') or options['SYS']
            sysinfo.delete 'sysObjectID'
            records = [sysinfo]
          else
            records = []
          end
          hfdh = @fake_descr_hash[host]

          @workhash[:interfaces] = @workhash[''] #
          if $debug and ($debug['workhash'] or $debug['workhash0'])
            puts "  workhash0"
            show_workhash @workhash
          end
          for pu in punits_d
            pu.options = vendor.options
            join_cat, join_key = pu.defs[:join]
            if join_cat
              for cat, wh in @workhash[pu.cat]
                if wh and @workhash[join_cat]
                  join_hash = @workhash[join_cat][wh[join_key]]
                  wh.merge! join_hash if join_hash
                end
              end
            end
            puts "  fix_workhash #{pu.class} #{pu.name}" if $debug
            pu.fix_workhash @workhash
          end
          @workhash.delete :interfaces #
          if $debug and ($debug['workhash'] or $debug['workhash1'])
            puts "  workhash1"
            show_workhash @workhash
          end

          for cat, wh in @workhash
            if (specs = DEFS.get_specs cat)
              (index_key = specs[:index_key] || specs[:named_index])
            else
              specs = {}
            end
            ign_proc = specs[:ignore?]
            for ind, h in wh
              h['_host'] = @hostname || host
              h['_key'] = if index_key
                            next if h[index_key].to_s.empty?
                            "#{cat}_#{key_encode h[index_key]}"
                          elsif ind.kind_of? Integer
                            "#{cat}#{ind}"
                          elsif ind.kind_of? Array
                            "#{cat}_#{ind.join(',')}"
                          else
                            "#{cat}_#{ind}"
                          end
              h['_interval'] = @interval
              h['_time'] = now_i
              if hfdh and (f_descr = hfdh[h['_key']]) and
                  (prop = specs[:prop]) and (descr_k = prop[:description])
                h[descr_k] = f_descr
              end
              puts "  record #{h.inspect}" if h['_d']
              next if ign_proc and ign_proc.call(h)
              records.push h
            end
          end
          @cb.call records
          @loop.detach self
        }
      }
    end

    def on_detach
      @snmp.close rescue nil
    end

    def key_encode s
      s.to_s.gsub(/[:\/]/, '-').gsub(/[ =]/, '_').gsub(/[^-a-zA-Z0-9_.]/) { #/
        "%02X"%$&.unpack('C').first}
    end

    def poll1 punits, &cb
      if punits.empty?
        cb.call
      else
        pu = punits.shift
        @get_oid_buf = []
        oids = pu.oids.dup
        puts "  poll #{host} #{pu.name}" if $debug
        walk1(pu, oids) {poll1 punits, &cb}
      end
    end

    def walk1 pu, oids, &cb
      wh = @workhash[pu.cat]
      if oids.empty?
        if @get_oid_buf.empty?
          cb.call
        else
          varbind = BER.cat_enoid @get_oid_buf
          get(varbind) {|results|
            results.each {|enoid, tag, val| pu.feed wh, enoid, tag, val}
            cb.call
          }
        end
      else
        if (req_enoid = oids.shift) and req_enoid.getbyte(-1) == 0
          @get_oid_buf.push req_enoid
          walk1 pu, oids, &cb
        else
          walk(req_enoid) {|results|
            show_results req_enoid, results if $debug and $debug['walk']
            results.each {|enoid, tag, val| pu.feed wh, enoid, tag, val}
            walk1 pu, oids, &cb
          }
        end
      end
    end

    def show_workhash workhash
      for cat, wh in workhash
        puts "    cat: #{cat.inspect}"
        for ind, h in wh
          puts "      index: #{ind}"
          for k, v in h
            puts "        #{k}: #{v.inspect}"
          end
        end
      end
    end

    def show_results req_enoid, results
      puts "    req #{SNMP.enoid2name req_enoid}"
      for enoid, tag, val in results
        a = BER.dec_oid enoid
        s = a[0..-2].join('.')
        oid_ind = BER.enc_v_oid s
        puts "      res #{SNMP.enoid2name(enoid)} #{tag} #{val.inspect}"
      end
    end

    def walk enoid, &cb
      @results.clear
      @retry_count = 0
      @poll_cb = cb
      @snmp.connect unless @snmp.sock
      @snmp.walk_start(enoid) {|*res| @results.push res}
      send_req enoid
    rescue SocketError
      @loop.detach self
      @on_error.call if @on_error
      Log.error "#{host}: error"
    end

    def get varbind, &cb
      @results.clear
      @retry_count = 0
      @poll_cb = cb
      @snmp.connect unless @snmp.sock
      @snmp.get_start(varbind) {|*res| @results.push res}
      send_req varbind
    rescue SocketError
      @loop.detach self
      @on_error.call if @on_error
      Log.error "#{host}: error"
    end

    def send_req arg
      @preq = [@snmp.state, arg]
      if (s = @snmp.make_req(@snmp.state, arg))
        if @retry_count > 0
          Log.debug "retry send_req, #{@buffers.size}"
        end
        @buffers.push s
        loop.watch @snmp.sock, :w, @tout, self
      else
        on_readable
      end
    end

    def retry
      if (@retry_count += 1) > 3
        @loop.detach self
        @on_error.call if @on_error
        Log.error "#{host}: error"
      elsif @preq
        Log.warn "#{host}: retry #{@retry_count}"
        @on_retry.call if @on_retry
        @buffers.push @preq.last
        loop.watch @snmp.sock, :w, @tout, self
      else
        @loop.detach self
        @on_error.call if @on_error
        Log.error "#{host}: cannot retry: #{@retry_count}"
      end
    end

    def on_writable io=nil
      unless @buffers.empty?
        @snmp.sock.send @buffers.join(''), 0
        @buffers.clear
        loop.watch @snmp.sock, :r, @tout, self
      end
    end

    def on_readable io=nil
      msg = @snmp.sock.recv 2000, 0
      arg = @snmp.recv_msg msg
      if arg
        @snmp.state = :SUCCESS if @snmp.state == :GET_REQ
      end
      if @snmp.state == :SUCCESS
        @poll_cb.call @results
        @preq = nil
      elsif @snmp.state != :IDLE
        send_req arg if arg
      end
    rescue SystemCallError
      @snmp.state = :IDLE
      Log.error "#{@host}: ERROR: #{$!}"
      @loop.detach self
      @on_error.call if @on_error
    end

    def on_timeout
      Log.error "#{@host}: ERROR: timeout"
      @on_error.call if @on_error
    end
  end
end
