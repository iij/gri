require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'gri/config'
require 'gri/pcollector'
require 'mock'

module GRI

class TestPCollector < Test::Unit::TestCase
  def setup
    path = File.expand_path(File.dirname(__FILE__) + '/root/testtab')
    config = Config.new
    config['gritab-path'] = path
    @app = AppCollector.new config
    lines = @app.load_target_lines config
    @targets = @app.get_targets_from_lines lines, config
  end

  def test_pcollector_get_ptargets
    targets = @targets

    basetime = Time.local(2013,4,1,10,5).to_i
    ptargets = @app.get_ptargets targets, basetime, 0
    ae 1, ptargets.size
    ae basetime.to_i, ptargets.keys.first

    ptargets = @app.get_ptargets targets, basetime, 1
    t = Time.local(2013,4,1,10,5).to_i
    hosts = ptargets[t].map {|n| targets[n].first}.sort
    ae ["host01", "host02", "host03", "host04", "host05", "localhost"], hosts

    basetime = Time.local(2013,4,1,10,0).to_i
    ptargets = @app.get_ptargets targets, basetime, 300
    t = Time.local(2013,4,1,10,0).to_i
    hosts = ptargets[t].map {|n| targets[n].first}.sort
    ae ["host00", "host01", "host02", "host03", "host04", "host05", "host06",
      "localhost"], hosts

    basetime = Time.local(2013,4,1,10,7).to_i
    ptargets = @app.get_ptargets targets, basetime, 300
    t = Time.local(2013,4,1,10,10).to_i
    hosts = ptargets[t].map {|n| targets[n].first}.sort
    ae ["host01", "host02", "host03", "host04", "host05", "localhost"], hosts

    basetime = Time.local(2013,4,1,10,7).to_i
    ptargets = @app.get_ptargets targets, basetime, 300, 120

    #for t, inds in ptargets.sort_by {|t,| t}
    #  p [Time.at(t), inds.map {|ind|targets[ind].first}]
    #end
  end

  def test_pcollector_server_loop
    @app.server_loop([], {}, nil, nil)
  end

  def test_pcollector_get_max_queue_size
    config = Config.new
    app = AppCollector.new config
    assert_kind_of Integer, @app.get_max_queue_size
  end

  def test_pcollector_fork_child
    @app.extend MockFork
    nproc = 2
    pids = @app.fork_child nil, nil, nproc, nil, nil, nil, nil
    ae nproc, pids.size
  end
end

end
