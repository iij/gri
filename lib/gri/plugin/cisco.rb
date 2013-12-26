SNMP.update   'ciscoMemoryPoolMIB'=>'1.3.6.1.4.1.9.9.48',
  'ciscoMemoryPoolObjects'=>'1.3.6.1.4.1.9.9.48.1',
  'ciscoMemoryPoolTable'=>'1.3.6.1.4.1.9.9.48.1.1',
  'ciscoMemoryPoolEntry'=>'1.3.6.1.4.1.9.9.48.1.1.1',
  'ciscoMemoryPoolName'=>'1.3.6.1.4.1.9.9.48.1.1.1.2',
  'ciscoMemoryPoolUsed'=>'1.3.6.1.4.1.9.9.48.1.1.1.5',
  'ciscoMemoryPoolFree'=>'1.3.6.1.4.1.9.9.48.1.1.1.6',
  'ciscoMemoryPoolLargestFree'=>'1.3.6.1.4.1.9.9.48.1.1.1.7',

  'cipMacTable'=>'1.3.6.1.4.1.9.9.84.1.2.1',
  'cipMacSwitchedPkts'=>'1.3.6.1.4.1.9.9.84.1.2.1.1.3',
  'cipMacSwitchedBytes'=>'1.3.6.1.4.1.9.9.84.1.2.1.1.4',

  'cipMacXTable'=>'1.3.6.1.4.1.9.9.84.1.2.3',
  'cipMacHCSwitchedPkts'=>'1.3.6.1.4.1.9.9.84.1.2.3.1.1',
  'cipMacHCSwitchedBytes'=>'1.3.6.1.4.1.9.9.84.1.2.3.1.2',

  'lcpu'=>'1.3.6.1.4.1.9.2.1',
  'busyPer'=>'1.3.6.1.4.1.9.2.1.56.0',
  'avgBusy1'=>'1.3.6.1.4.1.9.2.1.57.0',
  'avgBusy5'=>'1.3.6.1.4.1.9.2.1.58.0',

  'cpmCPUTotalPhysicalIndex'=>'1.3.6.1.4.1.9.9.109.1.1.1.1.2',
  'cpmCPUTotal5sec'=>'1.3.6.1.4.1.9.9.109.1.1.1.1.3',
  'cpmCPUTotal1min'=>'1.3.6.1.4.1.9.9.109.1.1.1.1.4',
  'cpmCPUTotal5min'=>'1.3.6.1.4.1.9.9.109.1.1.1.1.5',

  'ciscoEnvMonMIB'=>'1.3.6.1.4.1.9.9.13',
  'ciscoEnvMonObjects'=>'1.3.6.1.4.1.9.9.13.1',
  'ciscoEnvMonTemperatureStatusTable'=>'1.3.6.1.4.1.9.9.13.1.3',
  'ciscoEnvMonTemperatureStatusEntry'=>'1.3.6.1.4.1.9.9.13.1.3.1',
  'ciscoEnvMonTemperatureStatusDescr'=>'1.3.6.1.4.1.9.9.13.1.3.1.2',
  'ciscoEnvMonTemperatureStatusValue'=>'1.3.6.1.4.1.9.9.13.1.3.1.3',

  'cempMemPoolName'=>'1.3.6.1.4.1.9.9.221.1.1.1.1.3',
  'cempMemPoolUsed'=>'1.3.6.1.4.1.9.9.221.1.1.1.1.7',
  'cempMemPoolFree'=>'1.3.6.1.4.1.9.9.221.1.1.1.1.8',
  'cempMemPoolLargestFree'=>'1.3.6.1.4.1.9.9.221.1.1.1.1.9',
  'cempMemPoolHCFree'=>'1.3.6.1.4.1.9.9.221.1.1.1.1.20',
  'cempMemPoolHCLargestFree'=>'1.3.6.1.4.1.9.9.221.1.1.1.1.22',
  'cempMemPoolHCUsed'=>'1.3.6.1.4.1.9.9.221.1.1.1.1.26'

GRI::Vendor::DEFS.update '9'=>{
  :name=>'Cisco',
  :options=>{'ver'=>'2c', 'ifMIB'=>true, 'lcpu'=>true,
    'ciscoEnvMonTemperature'=>true},
  :firm_re=>/Software\s*\(([\w\d]+)/,
  :version_re=>/Version\s+([\.\d\w()]+)/,
  :after_initialize=>proc {|sysinfo, options|
    options.set_unless_defined 'entityu' if options['lccpu']
    if (sysdescr = sysinfo['sysDescr']) =~
        /\s(\S+)\s+Software \(([^\)]+)\).*Version ([^,\s]+)/
      sysinfo['_firm'] = $2
      sysinfo['_ver'] = $3
      sysinfo['_sysdescr'] = "IOS #{$1} Software (#{$2}), Version #{$3}"
    elsif sysdescr =~ /Cisco Systems(, Inc\.)? (\S+)[\s\S]*Catalyst Operating System.*Version (\S+)/
      sysinfo['_firm'] = $2
      sysinfo['_ver'] = $3
      sysinfo['_sysdescr'] = "Catalyst Operating System (#{$2}), Version #{$3}"
    end
  },
}

GRI::DEFS.update 'lcpu'=>{:pucat=>:cpu,
  :oid=>['busyPer', 'avgBusy1', 'avgBusy5'],
  :tdb=>['cpu', 'busyPer', 'avgBusy1', 'avgBusy5'],
  :ds=>['busyPer,busyper,GAUGE,MAX,LINE1,#ff4020',
    'avgBusy1,avgbusy1,GAUGE,MAX,LINE1,#40ff20',
    'avgBusy5,avgbusy5,GAUGE,MAX,LINE1,#4020ff'],
  :prop=>{:lastvalue=>'busyPer', :name=>'cpu'},
  :list=>['CPU BUSY', '%N,%L %%\r'],
  :graph=>[['percent', 0]],
},
  'ciscoEnvMonTemperature'=>{:cat=>:temperature,
  :oid=>['ciscoEnvMonTemperatureStatusEntry'],
  :tdb=>['t', 'ciscoEnvMonTemperatureStatusDescr',
    'ciscoEnvMonTemperatureStatusValue'],
  :ds=>['ciscoEnvMonTemperatureStatusValue,temperature,GAUGE'],
  :prop=>{:lastvalue=>'ciscoEnvMonTemperatureStatusValue',
    :name=>'ciscoEnvMonTemperatureStatusDescr'},
  :list=>['Temperature', '%N,%L &deg;C\r'],
  :graph=>[['degrees Celsius', 0, [0, 1000]]],
  :composite=>['v', 't'],
},
  'lccpu'=>{
  :oid=>['cpmCPUTotalPhysicalIndex', 'cpmCPUTotal5sec',
    'cpmCPUTotal1min', 'cpmCPUTotal5min'],
  :tdb=>['lccpu', 'entPhysicalDescr', 'entPhysicalName',
    'cpmCPUTotal5sec', 'cpmCPUTotal1min', 'cpmCPUTotal5min'],
  :join=>[:entityu, 'cpmCPUTotalPhysicalIndex'],
  :ds=>['cpmCPUTotal5sec,busyper,GAUGE,MAX,LINE1,#ff4020',
    'cpmCPUTotal1min,avgbusy1,GAUGE,MAX,LINE1,#40ff20',
    'cpmCPUTotal5min,avgbusy5,GAUGE,MAX,LINE1,#4020ff'],
  :prop=>{:description=>'entPhysicalDescr',
    :lastvalue=>'cpmCPUTotal5sec', :name=>'entPhysicalName'},
  :list=>['LC CPU BUSY', '%N,%D,%L %%\r'],
  :graph=>[['percent', 0]],
}
