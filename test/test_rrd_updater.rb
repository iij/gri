require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'fileutils'
require 'gri/updater'
require 'gri/utils'

module GRI

class TestRRDUpdater < Test::Unit::TestCase
  class MockRRD
    attr_accessor :daemon
    attr_reader :init_args, :updates

    def initialize *args
      @init_args = args
      @updates = []
    end

    def set_create_args *args
      @rrdname = args.shift
      @args = args
    end

    def buffered_update s
      @updates.push s
    end
  end

  def setup
    Config.init
    @tmp_dir = File.expand_path(File.dirname(__FILE__) + '/.t')
    Dir.mkdir @tmp_dir unless File.directory? @tmp_dir
  end

  def test_updater_get_tag_ary
    Config['tag-rule'] = '/^((AA\d+)\s+\S+)/ aa $2.downcase $2'
    Config['tag-rule'] = '/^((BB\d+)\s+\S+)/ bb $2.downcase $2'
    res = Updater.get_tag_ary 'BB01 aaa'
    ae 'bb01', res[0][1]
  end

  def test_updater_mk_rra_args
    updater = GRI::RRDUpdater.new :data_name=>''
    res = updater.mk_rra_args
    ae ["RRA:AVERAGE:0.5:12:9000", "RRA:MAX:0.5:1:20000",
      "RRA:MAX:0.5:12:9000", "RRA:MAX:0.5:144:2000"], res
    Config['rra-max'] = '300 9999'
    res = updater.mk_rra_args
    ae ["RRA:MAX:0.5:300:9999"], res
  end

  def test_update_sysdb
    path = "/tmp/.sysdb/sysdb.txt"
    FileUtils.rm_r File.dirname(path), :force=>true
    FileUtils.mkdir_p File.dirname(path)

    sysdb = {}
    Utils.update_ltsv_file path, '_host', sysdb
    ae 0, File.size(path)
    sysdb = {'host1'=>{'sysDescr'=>'Linux', '_host'=>'host1'}}
    Utils.update_ltsv_file path, '_host', sysdb
    sysdb = {'host2'=>{'sysDescr'=>'FreeBSD', '_host'=>'host2'}}
    Utils.update_ltsv_file path, '_host', sysdb
    FileUtils.rm_r File.dirname(path), :force=>true
  end

  def test_updater_create
    data_name = 'num'
    updater = GRI::RRDUpdater.new :data_name=>data_name
    ds_specs = GRI::DEFS.get_specs(data_name)[:ds]
    now_i = Time.now.to_i
    time = now_i - now_i % 300
    rrd = updater.create_rrd '/tmp/foo.rrd', time, 300, ds_specs, nil
    assert_kind_of RRD, rrd
  end

  def test_updater_mk_ds_args
    data_name = ''
    updater = RRDUpdater.new :data_name=>data_name
    specs = DEFS.get_specs data_name
    ds_specs = specs[:ds]
    ae 'ifInOctets,inoctet,DERIVE,MAX,AREA,#90f090,in,8', ds_specs.first
    ds_args, record_keys = updater.mk_ds_args ds_specs, 300
    ae 'DS:inoctet:DERIVE:750:U:U', ds_args.first
    ae 'ifInOctets', record_keys.first
  end

  def test_updater_update1
    dir = @tmp_dir
    basename = 'foo_num_test'
    rrd_path = "#{dir}/#{basename}.rrd"
    File.unlink rrd_path rescue nil
    data_name = 'num'
    updater = GRI::RRDUpdater.new :data_name=>data_name,
      :dir=>@tmp_dir, :host=>'foo', :index=>'test'

    # mk_update_str
    s = updater.mk_update_str [1, 2, 3, 4]
    ae '1:2:3:4', s
    s = updater.mk_update_str [1, 2, nil, 4]
    ae '1:2:U:4', s
    s = updater.mk_update_str [1, 'notnum', nil, 4]
    ae '1:U:U:4', s

    # update
    time = Time.now.to_i
    updater.update time, :number=>10
    updater.close
    assert File.exist?(rrd_path)
  end

  def test_updater_update2
    updater = RRDUpdater.new :data_name=>'', :dir=>'/var/tmp',
      :host=>'testhost', :index=>'eth0'
    updater.rrd_class = MockRRD
    time = Time.local(2013,4,1).to_i
    record = {'ifDescr'=>'eth0', 'ifInOctets'=>10, 'ifOutOctets'=>20,
      'ifInErrors'=>1, 'ifOutErrors'=>0, 'ifOperStatus'=>1, 'ifSpeed'=>1}
    updater.update time, record
    ae '1364742000:10:20:U:U:1:0:U:U:U:U', updater.rrd.updates.first
  end

  def test_update_records_file
    test_dir = File.expand_path(File.dirname(__FILE__))
    org_path = test_dir + '/root/gra/testhost/.records.txt'
    path = '/var/tmp/.records.txt'
    FileUtils.cp org_path, path

    h = {'new'=>{'_key'=>'new', 'a'=>1}}
    Utils.update_ltsv_file path, '_key', h

    rs = GRI::Utils.load_records File.dirname(path)
    ae '1', rs['new']['a']

    File.unlink path
  end
end

end
