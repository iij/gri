require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'rack'
require 'gri/log'
require 'gri/config'
require 'gri/ds_list'

module GRI

class TestDSList < Test::Unit::TestCase
  def setup
    @root_dir = File.expand_path(File.dirname(__FILE__) + '/root')
    gra_dir = @root_dir + '/gra'
    Config.init
    Config['gra-dir'] = gra_dir
  end

  def test_ds_list_get_data_hash
    dlist = DSList.new
    records = Utils.load_records Config['gra-dir'] + '/testhost'
    ae 'eth0', records['_eth0']['ifDescr']

    data_hash = dlist.get_data_hash records
    key, prop, = data_hash[''].first
    ae '_eth0', key
    ae 'eth0', prop[:name]

    s = dlist.format_cell '%D', prop
    ae '<td>testdescr</td>', s

    ae ['<td>eth0</td>', '<td>testdescr</td>'],
      dlist.format_tr(['%N', '%D'], prop)

    prop[:ipaddr] = '192.168.0.0/255.255.255.0'
    ae ['<td>192.168.0.0/24</td>'], dlist.format_tr(['%I'], prop)
  end

  def test_ds_list_mk_comp_links
    dlist = DSList.new
    comps = ['s', 'v']
    ckeys = ['_eth0', '_eth1']
    res = dlist.mk_comp_links comps, 'testhost', ckeys
    ae 2, res.size
    ae "<a href=\"?p=s&amp;r=testhost__eth0&amp;r=testhost__eth1\">stack</a>", res.first
  end
end

end
