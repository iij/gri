GRI::Vendor::DEFS.update '2636.1'=>{
  :name=>'Juniper',
  :options=>{'ver'=>'2c', 'ifMIB'=>true},
  :version_re=>/JUNOS\s+(\d[\.\d\w]*)/,
}
