require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'gri/rrd'

class TestRRD < Test::Unit::TestCase
  def setup
    @test_dir = File.expand_path(File.dirname(__FILE__))
  end

  def create_test_rrd path

  end

  def test_rrd_version
    rrd = RRD.new
    assert_match /\A1\.\d\z/, rrd.version
  end

  def test_remove_base_dir
    args = 'foo', 'bar', '/usr/local/gri/gra/host/host.rrd'
    rrd = RRD.new nil, nil
    res = rrd.remove_base_dir *args
    ae args, res
    base_dir = '/usr/local/gri/gra'
    rrd = RRD.new nil, base_dir
    res = rrd.remove_base_dir *args
    ae 'host/host.rrd', res[2]
    base_dir = '/usr/local/gri/gra'
    rrd = RRD.new nil, base_dir
    res = rrd.remove_base_dir *args
    ae 'host/host.rrd', res[2]
  end

  def test_rrd_create_and_graph
    s = Time.local(2012,12,19,9)
    rrd_path = '/var/tmp/test.rrd'
    File.unlink rrd_path rescue nil
    rrd = RRD.new
    rrd.set_create_args rrd_path, s - 300, 300,
      'DS:number:GAUGE:600:U:U RRA:MAX:0.5:1:1000'
    s.to_i.step((s+24*3600).to_i, 300) {|i|
      rrd.buffered_update "#{i}:#{i%3600/300}"
    }
    rrd.flush_buffer

    stime = Time.local(2012,12,19,9,0)
    etime = Time.local(2012,12,20,9,0)
    img = rrd.graphgen stime, etime,
      ["DEF:number=#{rrd_path}:number:MAX", "LINE1:number#ff0000:id"]
    open('/var/tmp/test.png', 'w') {|f| f.write img}
    assert(img.size > 0)
  end
end
