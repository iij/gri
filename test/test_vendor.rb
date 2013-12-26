require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'gri/builtindefs'
require 'gri/msnmp'
require 'gri/vendor'
require 'gri/plugin/ucdavis'
require 'gri/plugin/netsnmp'

module GRI

class TestVendor < Test::Unit::TestCase
  def test_vendor
    sysinfo = {}
    vendor = Vendor.check sysinfo
    ae 'unknown', vendor.name
    sysinfo = {'sysObjectID'=>''}
    vendor = Vendor.check sysinfo
    ae 'unknown', vendor.name

    sysinfo = {"sysName"=>"testhost.example.com",
      "sysObjectID"=>"+\006\001\004\001\277\b\003\002\n",
      "sysLocation"=>"Right here, right now.",
      "sysDescr"=>"Linux testhost.example.com 2.6.18-274.12.1.el5PAE #1 SMP Tue Nov 29 14:16:58 EST 2011 i686",
      "sysUpTime"=>1000000000}

    vendor = Vendor.check sysinfo
    assert vendor.options['interfaces']
    assert vendor.options['ifMIB']
    assert vendor.options['ucd-la']
    assert vendor.options['ucd-memory']
    assert_nil vendor.options['notexist']
    ae '2c', vendor.options['ver']
    ae 'Linux', sysinfo['_firm']

    vendor = Vendor.check sysinfo, 'interfaces'=>false
    assert !vendor.options['interfaces']
  end
end

end
