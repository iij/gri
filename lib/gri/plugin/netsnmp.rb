GRI::Vendor::DEFS.update '8072' => {
  :name=>'NetSNMP',
  :options=>{'ver'=>'2c', 'ifMIB'=>true,
    'ucd-la'=>true, 'ucd-pr'=>true, 'ucd-ext'=>true, 'ucd-memory'=>true,
    'ucd-systemstats'=>true, #'ucd-diskio'=>true,
    'hrStorage'=>true, 'hrMemorySize'=>true,
    'hrSystemNumUsers'=>true, 'hrSystemProcesses'=>true},
}
