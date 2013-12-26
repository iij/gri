SNMP.update 'ucdavis'=>'1.3.6.1.4.1.2021',
  'prEntry'=>'1.3.6.1.4.1.2021.2.1',
  'prNames'=>'1.3.6.1.4.1.2021.2.1.2',
  'prCount'=>'1.3.6.1.4.1.2021.2.1.5',

  'extEntry'=>'1.3.6.1.4.1.2021.8.1',
  'extNames'=>'1.3.6.1.4.1.2021.8.1.2',
  'extOutput'=>'1.3.6.1.4.1.2021.8.1.101',

  'dskEntry'=>'1.3.6.1.4.1.2021.9.1',
  'dskPath'=>'1.3.6.1.4.1.2021.9.1.2',
  'dskDevice'=>'1.3.6.1.4.1.2021.9.1.3',
  'dskTotal'=>'1.3.6.1.4.1.2021.9.1.6',
  'dskUsed'=>'1.3.6.1.4.1.2021.9.1.8',
  'dskPercent'=>'1.3.6.1.4.1.2021.9.1.9',
  'dskPercentNode'=>'1.3.6.1.4.1.2021.9.1.10',
  'dskTotalLow'=>'1.3.6.1.4.1.2021.9.1.11',
  'dskTotalHigh'=>'1.3.6.1.4.1.2021.9.1.12',
  'dskUsedLow'=>'1.3.6.1.4.1.2021.9.1.15',
  'dskUsedHigh'=>'1.3.6.1.4.1.2021.9.1.16',

  'laEntry'=>'1.3.6.1.4.1.2021.10.1',
  'laNames'=>'1.3.6.1.4.1.2021.10.1.2',
  'laLoad'=>'1.3.6.1.4.1.2021.10.1.3',

  'memory'=>'1.3.6.1.4.1.2021.4',
  'memTotalSwap'=>'1.3.6.1.4.1.2021.4.3.0',
  'memAvailSwap'=>'1.3.6.1.4.1.2021.4.4.0',
  'memTotalReal'=>'1.3.6.1.4.1.2021.4.5.0',
  'memAvailReal'=>'1.3.6.1.4.1.2021.4.6.0',
  'memTotalFree'=>'1.3.6.1.4.1.2021.4.11.0',
  'memShared'=>'1.3.6.1.4.1.2021.4.13.0',
  'memBuffer'=>'1.3.6.1.4.1.2021.4.14.0',
  'memCached'=>'1.3.6.1.4.1.2021.4.15.0',

  'systemStats'=>'1.3.6.1.4.1.2021.11',
  'ssCpuRawUser'=>'1.3.6.1.4.1.2021.11.50.0',
  'ssCpuRawNice'=>'1.3.6.1.4.1.2021.11.51.0',
  'ssCpuRawSystem'=>'1.3.6.1.4.1.2021.11.52.0',
  'ssCpuRawIdle'=>'1.3.6.1.4.1.2021.11.53.0',
  'ssCpuRawWait'=>'1.3.6.1.4.1.2021.11.54.0',
  'ssCpuRawKernel'=>'1.3.6.1.4.1.2021.11.55.0',
  'ssCpuRawInterrupt'=>'1.3.6.1.4.1.2021.11.56.0',
  'ssIORawSent'=>'1.3.6.1.4.1.2021.11.57.0',
  'ssIORawReceived'=>'1.3.6.1.4.1.2021.11.58.0',
  'ssRawInterrupts'=>'1.3.6.1.4.1.2021.11.59.0',
  'ssRawContexts'=>'1.3.6.1.4.1.2021.11.60.0',

  'diskIOTable'=>'1.3.6.1.4.1.2021.13.15.1',
  'diskIOIndex'=>'1.3.6.1.4.1.2021.13.15.1.1.1',
  'diskIODevice'=>'1.3.6.1.4.1.2021.13.15.1.1.2',
  'diskIONRead'=>'1.3.6.1.4.1.2021.13.15.1.1.3',
  'diskIONWritten'=>'1.3.6.1.4.1.2021.13.15.1.1.4',
  'diskIOReads'=>'1.3.6.1.4.1.2021.13.15.1.1.5',
  'diskIOWrites'=>'1.3.6.1.4.1.2021.13.15.1.1.6',
  'diskIONReadX'=>'1.3.6.1.4.1.2021.13.15.1.1.12',
  'diskIONWrittenX'=>'1.3.6.1.4.1.2021.13.15.1.1.13'

GRI::DEFS.update 'ucd-la'=>{:cat=>:l,
  :oid=>['laEntry'],
  :tdb=>['l', 'laNames', 'laLoad'],
  #:conv_val => Proc.new {|sym_oid, val|
  #  (sym_oid == 'laLoad') ? val.to_f : val
  #},
  :ds=>['laLoad,load,GAUGE,MAX,LINE1,#ff3333,load'],
  :prop=>{:lastvalue=>'laLoad', :name=>'laNames'},
  :list=>['Load Average', '%N,%L\r'],
  :graph=>[['load average', 0]],
  :composite=>['v', 't'],
},
  'ucd-pr'=>{:cat=>:proc,
  :oid=>['prEntry'],
  :tdb=>['p', 'prNames', 'prCount'],
  :ds=>['prCount,running,GAUGE,MAX,LINE1,#ff3333,process'],
  :prop=>{:lastvalue=>'prCount', :name=>'prNames'},
  :list=>['Process Count', '%N,%L\r'],
  :graph=>[['process count', 0]],
},
  'ucd-ext'=>{:cat=>:ext,
  :oid=>['extEntry'],
  :tdb=>['ucdext', 'extNames', 'extOutput'],
  :ds=>['extOutput,output,GAUGE'],
  :prop=>{:name=>'extNames'},
  :list=>['Extensible Output', '%N,%L\r'],
  :graph=>[['output', 0]],
},
  'ucd-dsk'=>{:cat=>:disk,
  :oid=>['dskEntry'],
  :tdb=>['d', 'dskPath', 'dskTotal', 'dskUsed', 'dskDevice'],
  :fix_workhash=>proc {|wh|
    for k, r in wh[:disk]
      if r['dskTotalLow']
        r['dskTotal'] = r['dskTotalHigh'].to_i * 4294967296 + r['dskTotalLow'].to_i
        r['dskUsed'] = r['dskUsedHigh'].to_i * 4294967296 + r['dskUsedLow'].to_i
      end
      r['dskTotal'] = r['dskTotal'].to_i * 1024
      r['dskUsed'] = r['dskUsed'].to_i * 1024
    end
  },
  :ds=>['dskUsed,used,GAUGE,MAX,AREA,#40ff40'],
  :prop=>{:ub=>'dskTotal', :lastvalue=>'dskUsed', :name=>'dskPath',
    :description=>'dskDevice',
  },
  :list_text=>['Disk Used', '%N,%D,%1024L / %1024U\r'],
  :graph=>[['"disk used"', 1024]],
},
  'ucd-memory'=>{:cat=>:ucdm,
  :oid=>['memory'],
  :fix_workhash=>lambda {|wh|
    if (h = wh[:ucdm]) and (h0 = h[0])
      ind = 0
      h0.keys.sort.each {|key|
        ind = {'memTotalSwap'=>0, 'memAvailSwap'=>1, 'memTotalReal'=>2,
          'memAvailReal'=>3, 'memTotalFree'=>4,
          'memShared'=>5, 'memBuffer'=>6, 'memCached'=>7}[key]
        h[ind] = {'dummyName'=>key.dup, 'dummyFree'=>h0[key] * 1024} if ind
      }
    end
  },
  :ds=>['dummyFree,free,GAUGE,MAX,LINE1,#4020ff,memory'],
  :prop=>{:lastvalue=>'dummyFree', :name=>'dummyName'},
  :list=>['UCD Memory', '%N,%1024L\r'],
  :graph=>[['bytes', 1024]],
  :composite=>['t'],
},
  'ucd-diskio'=>{:cat=>:diskio, :puclass=>'UCDDiskIO',
  :oid=>['diskIODevice', 'diskIOReads', 'diskIOWrites',
    'diskIONReadX', 'diskIONWrittenX'],
  :tdb=>['diskIO', 'diskIODevice', 'diskIOReads', 'diskIOWrites',
    'diskIONReadX', 'diskIONWrittenX'],
  :ds=>['diskIOReads,reads,DERIVE,MAX,AREA,#90f090',
    'diskIOWrites,writes,DERIVE,MAX,LINE1,#4020ff',
    'diskIONReadX,nread,DERIVE,MAX,AREA,#90f090',
    'diskIONWrittenX,nwritten,DERIVE,MAX,LINE1,#4020ff',],
  :list=>['Disk I/O', '%N'],
  :prop=>{:name=>'diskIODevice'},
  :graph=>[['access', 0, [0, nil], /reads|writes/],
    ['byte/sec', 1000, [0, nil], /nread|nwritten/],], #/
  :composite=>['v', 't'],
},
  'ucd-systemstats'=>{
  :oid=>['systemStats'],
  :tdb=>['systemstats', 'ssCpuRawUser', 'ssCpuRawNice',
    'ssCpuRawSystem', 'ssCpuRawIdle', 'ssCpuRawWait',
    'ssCpuRawKernel', 'ssCpuRawInterrupt',
    'ssRawInterrupts', 'ssRawContexts',
    'ssIORawSent', 'ssIORawReceived',
  ],
  :ds=>[
    'ssCpuRawKernel,ssCpuRawKernel,DERIVE,MAX,AREA,#0000ff',
    'ssCpuRawSystem,ssCpuRawSystem,DERIVE,MAX,STACK,#0000ff',
    'ssCpuRawUser,ssCpuRawUser,DERIVE,MAX,STACK,#ff8080',
    'ssCpuRawWait,ssCpuRawWait,DERIVE,MAX,STACK,#ffff80',
    'ssCpuRawIdle,ssCpuRawIdle,DERIVE,MAX,STACK,#80ff80',

    'ssRawContexts,ssRawContexts,DERIVE,MAX,AREA,#ff8080',
    'ssRawInterrupts,ssRawInterrupts,DERIVE,MAX,STACK,#80ff80',

    'ssIORawReceived,ssIORawReceived,DERIVE,MAX,AREA,#80ff80',
    'ssIORawSent,ssIORawSent,DERIVE,MAX,STACK,#ff8080',
  ],
  :list=>['System Stats', '%N'],
  :prop=>{:name=>'systemStats'},
  :graph=>[['"CPU time"', 0, [0, nil], /Idle|Wait|User|System|Kernel/],
    ['num', 0, [0, nil], /Interrupts|Contexts/],
    ['blocks', 0, [0, nil], /Sent|Received/],
    #['blocks', 0, nil, /ssIORaw/],
  ],
}

GRI::Vendor::DEFS.update '2021'=>[
  'UCDavis',
  {'ver'=>'2c', 'ifMIB'=>true,
    'ucd-la'=>true, 'ucd-dsk'=>true, 'ucd-pr'=>true, 'ucd-ext'=>true,
    'ucd-memory'=>true, 'ucd-systemstats'=>true,},
]
