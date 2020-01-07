GRI::DEFS['interfaces'].update :ignore? => proc {|record|
  /(^(|Loopback|Null|Async)\d+)|(^veth\w)|cef layer|atm subif/ ===
    record['ifDescr']
},
  :exclude? => proc {|record|
  record['ifOperStatus'].to_i != 1 or
    record['ifSpeed'].to_i == 0 or
    (record['ifInOctets'].to_i == 0 and
     record['ifOutOctets'].to_i == 0) or
    /(^(|Loopback|Null|Async|lo)\d+)|(^veth\w)|cef layer|atm subif/ ===
    record['ifDescr']
},
  :hidden? => proc {|record|
  /(^veth\w)|cef layer|atm subif|unrouted.VLAN/ === record['ifDescr']
}
