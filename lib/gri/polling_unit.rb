module GRI
  class PollingUnit
    UNITS = {}

    attr_reader :name, :cat, :oids
    attr_accessor :dhash
    alias :defs :dhash

    def self.all_units
      if UNITS.empty?
        for name, dhash in DEFS
          next unless String === name
          pucat = dhash[:cat] || dhash[:pucat] ||
            (dhash[:tdb] and dhash[:tdb].first.intern) || name.intern
          puclass = dhash[:puclass]
          if puclass and Object.const_defined?(puclass + 'PollingUnit')
            klass = eval(puclass + 'PollingUnit')
          else
            klass = self
          end
          pu = klass.new name, pucat
          pu.dhash = dhash
          pu.set_oids dhash[:oid]

          self::UNITS[name] = pu
        end
      end
      self::UNITS
    end

    def initialize name, cat
      @name = name
      @cat = cat
      @d_p = false
    end

    def set_oids names
      @oids = (names || []).map {|name|
        (oid = SNMP::OIDS[name]) ? BER.enc_v_oid(oid) :
          (Log.debug "No such OID: #{name}"; nil)
      }.compact
    end

    def feed wh, enoid, tag, val
      if (feed_proc = dhash[:feed])
        puts "  feed_proc #{[enid, tag, val].inspect}" if @d_p
        feed_proc.call wh, enoid, tag, val
      else
        if enoid.getbyte(-2) < 128
          ind = enoid.getbyte(-1)
          if ind == 0
            oid_ind = enoid
          else
            oid_ind = enoid[0..-2]
          end
        else
          if enoid.getbyte(-3) < 128
            ind = ((enoid.getbyte(-2) & 0x7f) << 7) + enoid.getbyte(-1)
            oid_ind = enoid[0..-3]
          else
            tmpary = BER.dec_oid enoid
            oid_ind = BER.enc_v_oid(tmpary[0..-2].join('.'))
            ind = tmpary[-1]
          end
        end
        if (sym_oid = SNMP::ROIDS[oid_ind])
          (conv_val_proc = dhash[:conv_val]) and
            (val = conv_val_proc.call(sym_oid, val))
          (wh[ind] ||= {})[sym_oid] = val
          if @d_p
            wh[ind]['_d'] = true
            puts "  feed #{[sym_oid, ind, tag, val].inspect}"
          end
        end
      end
    end

    def fix_workhash workhash
      if (c = dhash[:fix_workhash])
        c.call workhash
      end
    end

    def inspect
      "#<PU:#{@name}>"
    end
  end
end
