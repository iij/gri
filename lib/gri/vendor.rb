module GRI
  class Vendor
    DEFS = {}
    class <<DEFS
      alias :update :merge!
    end

    attr_reader :name, :options

    def self.check sysinfo, options={}
      vdefs = nil
      if !(sysobjectid = sysinfo['sysObjectID']) or sysobjectid.size < 5
      else
        sysoid = BER.dec_oid(sysobjectid[5..-1])
        sysoid.size.downto(1) {|n|
          sysoidkey = sysoid[0, n].map {|noid| noid.to_s}.join('.')
          if (vdefs = self::DEFS[sysoidkey])
            if Array === vdefs
              vname, voptions, f_re, v_re = vdefs
              vdefs = {:name=>vname, :options=>voptions,
                :firm_re=>f_re, :version_re=>v_re}
            end
            break
          end
        }
      end
      vdefs ||= {:name=>'unknown'}
      Vendor.new vdefs, sysinfo, options
    end

    def initialize vdefs, sysinfo, options
      @name = vdefs[:name]
      @sysinfo = sysinfo
      @options = {'ver'=>'1', 'interfaces'=>true, 'ipaddr'=>true}
      @options.merge! vdefs[:options] if vdefs[:options]
      @options.merge! options if options
      class <<@options
        def set_unless_defined k, v=true
          self[k] = v unless self.has_key? k
        end
      end
      sysinfo['_firm'] = get_firm vdefs[:firm_re], sysinfo
      sysinfo['_ver'] = get_ver vdefs[:version_re], sysinfo
      sysinfo['_sysdescr'] = sysinfo['sysDescr']
      if (cb = vdefs[:after_initialize])
        cb.call @sysinfo, @options
      end
    end

    def get_firm f_re, sysinfo
      sysdescr = sysinfo['sysDescr'] || '?'
      if f_re
        match = f_re.match sysdescr
        match ? match[1] : '?'
      else
        (f = sysdescr.scan(/\A([-\w]+)/).first) ? f[0] : '?'
      end
    end

    def get_ver v_re, sysinfo
      sysdescr = sysinfo['sysDescr'] || '?'
      if v_re
        match = v_re.match sysdescr
        match ? match[1] : '?'
      else
        tmp, = sysdescr.scan(/(\d+\.[\.\d]+)/).first
        tmp || '?'
      end
    end

    def get_punits
      units = PollingUnit.all_units
      options.keys.map {|k| options[k] ? units[k] : nil}.compact
    end
  end
end
