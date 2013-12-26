require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'gri/config'

module GRI

class TestConfig < Test::Unit::TestCase
  def test_config
    conf = GRI::Config.new
    conf['key'] = 1
    ae 1, conf['key']
    conf['key'] = 'a'
    ae 'a', conf['key']
    ae [1, 'a'], conf.getvar('key')

    conf[:s] = 'aaa'
    ae({"key"=>[1, "a"], :s=>"aaa"}, conf.to_h)

    assert_nil conf['notexist']

    conf['key2'] = false
    assert !conf['key2']
    assert conf.has_key?('key2')
    assert !conf.has_key?('key3')

    Config.init
    assert_nil Config['key']
    Config['key'] = 1
    ae 1, Config['key']
    Config['key'] = 'a'
    ae 'a', Config['key']
    ae [1, 'a'], Config.getvar('key')
    assert conf.has_key?('key')
  end

  def test_load_from_file
    path = File.expand_path(File.dirname(__FILE__) + '/root/test.conf')
    conf = GRI::Config.load_from_file path
    ae 1, conf['test-opt-num'].to_i
    ae 'foo', conf['test-opt-str']
    ae ["/dir1", "/dir2"], conf.getvar('plugin-dir')
  end

  def test_get_targets_from_lines
    lines = ['localhost ver=2c community=public', 'testhost community=xxxxxx']
    targets = GRI::Config.get_targets_from_lines lines
    host, options = targets.first
    ae 'localhost', host
    ae '2c', options['ver']
    ae 'public', options['community']
    assert !options['interfaces']

    lines = ['exhost type=exec cmd="vmstat 1 3|tail -1" ' +
      'out_keys=procs_r,procs_b,memory_swpd,memory_free,memory_buff']
    targets = GRI::Config.get_targets_from_lines lines
    host, options = targets.first
    ae 'exec', options['type']
    ae 'vmstat 1 3|tail -1', options['cmd']
  end
end

end
