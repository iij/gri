require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'rack'
require 'gri/log'
require 'gri/config'
require 'gri/builtindefs'
require 'gri/grapher'
require 'gri/list'
require 'gri/msnmp'
require 'gri/vendor'
require 'gri/plugin/ucdavis'

module GRI

class TestList < Test::Unit::TestCase
  def setup
    @root_dir = File.expand_path(File.dirname(__FILE__) + '/root')
    gra_dir = @root_dir + '/gra'
    Config.init
    Config['gra-dir'] = gra_dir
    @list = List.new
    @app = Rack::MockRequest.new @list
  end

  def test_mk_regexp
    s = '1a.*#'
    list = List.new
    ae "1a\\.\\*\\#", list.mk_regexp(s).source
    list = List.new :use_regexp_search=>'on'
    ae "1a.*\\#", list.mk_regexp(s).source
  end

  def test_load_sysdb
    sysdb = @list.load_sysdb Config.getvar('gra-dir')
    assert_match /Linux host.example.com/, sysdb['192.168.0.1']['sysDescr']
  end

  def test_list
    res = @app.get '/'
    ae 200, res.status
  end

  def test_list_sysdb_list
    dirs = Config.getvar 'gra-dir'
    sysdb = {}
    params = {}
    lines = @list.sysdb_list dirs, sysdb, params
    ae [], lines
    sysdb = {'host1'=>{}, 'host2'=>{}}
    lines = @list.sysdb_list dirs, sysdb, params
    ae ['host1', 'host2'], lines.map {|h, s| h}
  end

  def test_list_grep_graph
    dirs = Config.getvar 'gra-dir'
    sysdb = @list.load_sysdb dirs
    hlines = @list.sysdb_list dirs, sysdb, {}
    hosts = hlines.map {|h, l| h}
    res = @list.grep_graph dirs, hosts, {}
    ae 2, res.values.first.size
    ae '', res.values.first.first.first
  end
end

end
