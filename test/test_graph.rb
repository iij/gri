require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'gri/graph'

module GRI

class TestGraph < Test::Unit::TestCase
  def setup
    @root_dir = File.dirname(__FILE__) + '/root'
    @graph = Graph.new :dir=>'/var/tmp'
  end

  def test_graph_get_rrdpaths_and_ub
    gra_dirs = [@root_dir + '/gra']
    rs = ['testhost__eth0']
    graph = Graph.new :dirs=>gra_dirs
    res = graph.get_rrdpaths_and_ub rs
    ae 1000000000, res[1]
  end

  def test_graph_mk_graph_title
    gra_dirs = [@root_dir + '/gra']
    rs = ['testhost__eth0']
    graph = Graph.new :dirs=>gra_dirs
    params = {}
    res = graph.mk_graph_title rs, params
    assert_nil res

    params = {'p'=>'t'}
    res = graph.mk_graph_title rs, params
    ae '"testhost eth0 testdescr"', res
  end

  def test_graph_mk_graph_args
    rrdpaths = ['/usr/local/gri/gra/host00__eth0.rrd',
      '/usr/local/gri/gra/host01__eth0.rrd',]
    params = {'p'=>''}
    specs = DEFS.get_specs ''
    res = @graph.mk_graph_args specs, rrdpaths, params
    assert_match /\A-v\s+"bps"/, res[0]
    assert_match /\A--base\s+1000/, res[1]
    assert_match /\A--lower-limit\s+0/, res[2]
    exprs = res[3].split
    assert_match /\ADEF:v1inoctet=/, exprs[0]
    assert_match /\ADEF:v2inoctet=/, exprs[1]
    assert_match /\ACDEF:inoctet0=/, exprs[2]
    assert_match /\AAREA:inoctet0#/, exprs[3]
    assert_match /\AGPRINT:inoctet0:/, exprs[4]
    exprs = res[4].split
    assert_match /\ADEF:v1outoctet=/, exprs[0]
    assert_match /\ADEF:v2outoctet=/, exprs[1]
    assert_match /\ACDEF:outoctet0=/, exprs[2]
    assert_match /\ALINE1:outoctet0#/, exprs[3]
    assert_match /\AGPRINT:outoctet0:/, exprs[4]
  end

  def test_graph_mk_defstr
    rrdpaths = ['/usr/local/gri/gra/host00__eth0.rrd',
      '/usr/local/gri/gra/host01__eth0.rrd',]
    params = {'fmt'=>'json'}
    specs = DEFS.get_specs ''
    ds_specs = specs[:ds].grep /Octets/
    res = @graph.mk_defstr ds_specs, rrdpaths, params, nil
    assert_match /XPORT:inoctet0:"in"/, res[0]
    assert_match /XPORT:outoctet0:"out"/, res[1]
  end
end

end
