require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'gri/builtindefs'
require 'gri/msnmp'
require 'gri/vendor'
require 'gri/plugin/ucdavis'

module GRI

class TestBuiltinDEFS < Test::Unit::TestCase
  def setup
  end

  def test_get_specs
    specs = DEFS.get_specs 'num'
    ae '_index', specs[:prop][:name]
    ae 4, specs[:rra].size
    specs = DEFS.get_specs ''
    ae 'ifInOctets,inoctet,DERIVE,MAX,AREA,#90f090,in,8', specs[:ds].first
    specs = DEFS.get_specs :l
  end

  def test_get_specs_foo
    specs = DEFS.get_specs :foo
    assert_nil specs
    DEFS.instance_eval {@specs = nil}
    DEFS['foo'] = {:tdb=>['foo', 'xx * 10', 'yy', 'zz']}
    specs = DEFS.get_specs :foo
    ae ['foo', 'xx', 'yy', 'zz'], specs[:tdb]
  end
end

end
