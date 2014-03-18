module GRI
  DEFS = {
    'num'=>{
      :ds=>['num,num,GAUGE,,,,:index'],
      :rra=>['RRA:AVERAGE:0.5:15:10000',
        'RRA:MAX:0.5:1:50000', 'RRA:MAX:0.5:15:10000', 'RRA:MAX:0.5:180:10000'],
      :prop=>{:name=>'_index', :description=>'description', :lastvalue=>'num'},
      :list=>['Num', '%N,%L\r'],
      :graph=>[['', 0]],
      :composite=>['', 's', 'v', 't'],
    },
    'grimetrics'=>{:ds=>['number,number,GAUGE'],
      :prop=>{:name=>'_index'},
      :list_text=>['grimetrics', '%N,%L\r'],
      :composite=>['s'],
      :graph=>[['n', 0]],
    },

    'interfaces'=>{:cat=>'',
      :oid=>['ifDescr', 'ifSpeed', 'ifAdminStatus', 'ifOperStatus', 'ifType',
        'ifInOctets', 'ifOutOctets',
        'ifInDiscards', 'ifOutDiscards',
        'ifInErrors', 'ifOutErrors',
        'ifInUcastPkts', 'ifOutUcastPkts',
        'ifInNUcastPkts', 'ifOutNUcastPkts',],
      :index_key => 'ifDescr',
      :ignore? => proc {|record|
        /(^(Loopback|Null|Async)\d+)|cef layer|atm subif/ === record['ifDescr']},
      :exclude? => proc {|record|
        record['ifOperStatus'].to_i != 1 or
          record['ifSpeed'].to_i == 0 or
          (Integer(record['ifInOctets']) == 0 and
           Integer(record['ifOutOctets']) == 0) or
          /(^(Loopback|Null|Async|lo)\d+)|cef layer|atm subif/ === record['ifDescr']
      },
      :hidden? => proc {|record|
        /cef layer|atm subif|unrouted.VLAN/ === record['ifDescr']
      },
      :tdb=>['', 'ifDescr', 'ifAlias', 'ifSpeed',
        'ifInOctets', 'ifOutOctets', 'ifInDiscards', 'ifOutDiscards',
        'ifInErrors', 'ifOutErrors', 'ifHCInOctets', 'ifHCOutOctets',],
      :ds=>['ifInOctets,inoctet,DERIVE,MAX,AREA,#90f090,in,8',
        'ifOutOctets,outoctet,DERIVE,MAX,LINE1,#0000ff,out,8',
        'ifInDiscards,indiscard,DERIVE,MAX,LINE1,#00ff0f',
        'ifOutDiscards,outdiscard,DERIVE,MAX,LINE1,#00afff',
        'ifInErrors,inerror,DERIVE,MAX,LINE1,#ff0f0f',
        'ifOutErrors,outerror,DERIVE,MAX,LINE1,#ffaf00',
        'ifInUcastPkts,inucast,DERIVE,MAX,LINE1,#90f090',
        'ifOutUcastPkts,outucast,DERIVE,MAX,LINE1,#0000ef',
        'ifInNUcastPkts,innucast,DERIVE,MAX,LINE1,#ff0f0f',
        'ifOutNUcastPkts,outnucast,DERIVE,MAX,LINE1,#ffaf00'],
      :prop=>{:name=>'ifDescr', :description=>'ifAlias',
        :ostatus=>'ifOperStatus', :astatus=>'ifAdminStatus',
        :ipaddr=>'ipaddr', :ub=>'ifSpeed',},
      :list=>['Status,Interface,Description,IP Address', '%S,%N,%D,%I'],
      :graph=>[['bps', 1000, [0, nil], /Octets/],
        ['pps', 1000, [0, nil], /N?UcastPkts/],
        ['packets/5min', 1000, [0, nil], /Error|Discard/]], #/
      :composite=>['s', 'v', 't'],
    },
    'ifMIB'=>{:cat=>'',
      :oid=>['ifHCInOctets', 'ifHCOutOctets', 'ifHighSpeed', 'ifAlias'],
      :fix_workhash=>proc {|wh|
        for k, r in wh['']
          r['ifInOctets'] = r['ifHCInOctets'] if r['ifHCInOctets']
          r['ifOutOctets'] = r['ifHCOutOctets'] if r['ifHCOutOctets']
          if r['ifHighSpeed'] and r['ifHighSpeed'].to_i > 4000
            r['ifSpeed'] = r['ifHighSpeed'].to_i * 1_000_000
          end
        end
      },
    },
    'ipaddr'=>{
      :oid=>['ipAdEntIfIndex', 'ipAdEntNetMask'],
      :feed => lambda {|h, enoid, tag, val|
        ind = BER.dec_oid(enoid[9..-1]).join('.')
        h[ind] ||= {}
        if tag == 2
          h[ind]['ifIndex'] = val
        elsif tag == 0x40 # IPv4 Addr
          h[ind]['mask'] = val
        end
      },
      :fix_workhash => lambda {|wh|
        ifrecord = wh[''] || {}
        for k, record in wh[:ipaddr]
          a = k + '/' + record['mask']
          ind = record['ifIndex']
          if (r = ifrecord[ind])
            if r['ipaddr']
              r['ipaddr'] += ',' + a
            else
              r['ipaddr'] = a
            end
          end
        end
        wh.delete :ipaddr
      },
    },
    'tcp'=>{
      :oid=>['tcpCurrEstab', 'tcpActiveOpens',
        'tcpPassiveOpens', 'tcpAttemptFails', 'tcpEstabResets',
        'tcpInSegs', 'tcpOutSegs', 'tcpRetransSegs',
        'tcpInErrs', 'tcpOutRsts',],
      :tdb=>['tcp', 'tcpCurrEstab', 'tcpActiveOpens',
        'tcpPassiveOpens', 'tcpAttemptFails', 'tcpEstabResets',
        'tcpInSegs', 'tcpOutSegs', 'tcpRetransSegs',
        'tcpInErrs', 'tcpOutRsts',],
      :ds=>[
        'tcpCurrEstab,tcpCurrEstab,GAUGE,MAX,AREA,#90f090',
        'tcpActiveOpens,tcpActiveOpens,DERIVE,MAX,LINE1,#0000ff',
        'tcpPassiveOpens,tcpPassiveOpens,DERIVE,MAX,LINE1,#c000ff',
        'tcpAttemptFails,tcpAttemptFails,DERIVE,MAX,LINE1,#ff0000',
        'tcpEstabResets,tcpEstabResets,DERIVE,MAX,LINE1,#ff9030',

        'tcpInSegs,tcpInSegs,DERIVE,MAX,AREA,#99ff99',
        'tcpOutSegs,tcpOutSegs,DERIVE,MAX,LINE1,#0000ff',
        'tcpRetransSegs,tcpRetransSegs,DERIVE,MAX,LINE1,#00ffff',
        'tcpInErrs,tcpInErrs,DERIVE,MAX,LINE1,#ff0000',
        'tcpOutRsts,tcpOutRsts,DERIVE,MAX,LINE1,#ff9030',
      ],
      :prop=>{:name=>'tcp'},
      :list=>['TCP'],
      :graph=>[
        ['connection', 0, [0, nil],
          /tcp(CurrEstab|ActiveOpens|PassiveOpens|AttemptFails|EstabResets)/],
        ['packet/sec', 0, [0, nil],
          /tcp(InSegs|OutSegs|RetransSegs|InErrs|OutRsts)/]
      ],
    },
    'udp'=>{
      :oid=>['udpInDatagrams', 'udpOutDatagrams',
        'udpNoPorts', 'udpInErrors'],
      :tdb=>['udp', 'udpInDatagrams', 'udpOutDatagrams',
        'udpNoPorts', 'udpInErrors'],
      :ds=>[
        'udpInDatagrams,udpInDatagrams,DERIVE,MAX,AREA,#90f090',
        'udpOutDatagrams,udpOutDatagrams,DERIVE,MAX,LINE1,#0000ef',
        'udpNoPorts,udpNoPorts,DERIVE,MAX,LINE1,#00afff',
        'udpInErrors,udpInErrors,DERIVE,MAX,LINE1,#ff0f0f',
      ],
      :prop=>{:name=>'udp'},
      :list=>['UDP'], :graph=>[['"datagram/sec"', 0, [0, nil]]],
    },

    'entityu'=>{:oid=>['entPhysicalDescr', 'entPhysicalName'],},

    'hrSystemNumUsers'=>{
      :oid=>['hrSystemNumUsers'],
      :tdb=>['hrsystemnumusers', 'hrSystemNumUsers'],
      :ds=>['hrSystemNumUsers,users,GAUGE,MAX,LINE1,#ff4020,users'],
      :prop=>{:name=>'users', :lastvalue=>'hrSystemNumUsers'},
      :graph=>[['"users"', 0]],
      :list=>['Users', '%N, %L\r'],
    },

    'hrStorage'=>{
      :oid=>['hrStorageEntry'],
      :exclude? => proc {|record| record['hrStorageDescr'] =~ /devicemapper/},
      :hidden? => proc {|record| record['hrStorageDescr'] =~ /devicemapper/},
      :tdb=>['hrStorage', 'hrStorageDescr', 'hrStorageSize', 'hrStorageUsed'],
      :fix_workhash=>lambda {|wh|
        if (h = wh[:hrStorage])
          h.reject! {|k, v|
            v['hrStorageType'] != "+\x06\x01\x02\x01\x19\x02\x01\x04"}
          h.each {|k, v|
            u = v['hrStorageAllocationUnits'].to_i
            v.delete 'hrStorageType'
            v['hrStorageSize'] = v['hrStorageSize'].to_i * u
            v['hrStorageUsed'] = v['hrStorageUsed'].to_i * u
          }
        end
      },
      :ds=>['hrStorageUsed,used,GAUGE,MAX,AREA,#40ff40'],
      :prop=>{:name=>'hrStorageDescr',
        :lastvalue=>'hrStorageUsed', :ub=>'hrStorageSize'},
      :list=>['Storage Used', '%N, %1024L / %1024U\r'],
      :graph=>[['storage used', 1024]],
      :composite=>['s', 'v', 't'],
    },

    :term => {
      :default=>[['Daily', 30*3600], ['Weekly', 8*24*3600],
        ['Monthly', 31*24*3600], ['Yearly', 365*24*3600]],
      :short=>[['Last 3 hours', 3*3600], ['Daily', 30*3600],
        ['Weekly', 8*24*3600], ['Monthly', 31*24*3600]],
      :long=>[['Weekly', 8*24*3600], ['Monthly', 31*24*3600],
        ['Yearly', 365*24*3600], ['Last 6 years', 6*365*24*3600]],
      :verylong=>[['Monthly', 31*24*3600], ['Yearly', 365*24*3600],
        ['Last 8 years', 8*365*24*3600]],
    }
  }

  class <<DEFS
    alias :update :merge!
    def get_specs key
      unless @specs
        @specs = {}
        for k, dhash in self
          next unless String === k
          data_name = dhash[:data_name] || dhash[:cat] ||
            (dhash[:tdb] and dhash[:tdb].first) ||
            k.gsub(/-/, '')
          spec = (@specs[data_name.to_s] ||= {})
          [:list, :index_key, :named_index, :tdb, :ds, :rra, :prop,
            :graph, :composite, :ignore?, :exclude?, :hidden?].each {|symkey|
            spec[symkey] = dhash[symkey] if dhash[symkey]
          }
          spec[:list] ||= dhash[:list_text] #XXX
        end
      end
      @specs[key.to_s]
    end
  end
end
