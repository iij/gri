require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'gri/msnmp'
require 'gri/builtindefs'
require 'gri/vendor'
require 'gri/plugin/cisco'

module GRI

class TestPluginCisco < Test::Unit::TestCase
  def test_plugin_cisco
    sysinfo = {'sysObjectID'=>"+\x06\x01\x04\x01\t\x01",
      'sysDescr'=>"Cisco IOS Software, c9999x00000_rp Software (c9999x00000_xx), Version 12.3(45)X678, RELEASE SOFTWARE ()",
      }
    vendor = Vendor.check sysinfo
    assert vendor.options['interfaces']
    assert vendor.options['lcpu']
    ae '2c', vendor.options['ver']
    ae 'c9999x00000_xx', sysinfo['_firm']
  end
end

end
