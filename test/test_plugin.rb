# coding: us-ascii
require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'gri/config'
require 'gri/plugin'

module GRI

class TestPlugin < Test::Unit::TestCase
  def test_plugin_load_plugin_dir
    lib_dir = File.dirname(__FILE__) + '/../lib/gri/plugin'
    files = GRI::Plugin.get_plugin_files lib_dir
    assert(files.size > 5)

    config = Config.new
    config['enable-plugin'] = 'ucdavis'
    files = GRI::Plugin.get_plugin_files lib_dir, config
    ae 1, files.size

    config['enable-plugin'] = 'netsnmp'
    files = GRI::Plugin.get_plugin_files lib_dir, config
    ae 2, files.size

    config['disable-plugin'] = 'ucdavis'
    files = GRI::Plugin.get_plugin_files lib_dir, config
    ae 1, files.size
  end

require 'gri/msnmp'
require 'gri/builtindefs'
require 'gri/vendor'
require 'gri/polling_unit'
require 'gri/plugin/ucdavis'

  DATA = [
    ["+\x06\x01\x04\x01\x8Fe\t\x01\x01\x01", 2, 1],
    ["+\x06\x01\x04\x01\x8Fe\t\x01\x02\x01", 4, "/"],
    ["+\x06\x01\x04\x01\x8Fe\t\x01\x06\x01", 2, 40_000_000],
    ["+\x06\x01\x04\x01\x8Fe\t\x01\a\x01", 2, 25_000_000],
    ["+\x06\x01\x04\x01\x8Fe\t\x01\b\x01", 2, 9_000_000],
  ]

  def test_plugin_ucdavis_feed
    SNMP.new 'host'
    vendor = Vendor.check({}, {'ucd-dsk'=>true})
    pu = vendor.get_punits.detect {|pu| pu.name == 'ucd-dsk'}

    wh = {}
    DATA.each {|enoid, tag, val|
      pu.feed wh, enoid, tag, val}
    h = wh[1]
    ae '/', h['dskPath']
    ae 40000000, h['dskTotal']
    ae 9000000, h['dskUsed']

    pu.fix_workhash :disk=>wh
    ae 40000000*1024, h['dskTotal']
    ae 9000000*1024, h['dskUsed']
  end
end

end
