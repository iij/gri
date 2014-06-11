GRI::DEFS['interfaces'].update :ignore? => proc {|record|
  /(^(|Loopback|Null|Async)\d+)|(^veth\w)|cef layer|atm subif/ ===
    record['ifDescr']
},
  :exclude? => proc {|record|
  record['ifOperStatus'].to_i != 1 or
    record['ifSpeed'].to_i == 0 or
    (Integer(record['ifInOctets']) == 0 and
     Integer(record['ifOutOctets']) == 0) or
    /(^(|Loopback|Null|Async|lo)\d+)|(^veth\w)|cef layer|atm subif/ ===
    record['ifDescr']
},
  :hidden? => proc {|record|
  /(^veth\w)|cef layer|atm subif|unrouted.VLAN/ === record['ifDescr']
}
