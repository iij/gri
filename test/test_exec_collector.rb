require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'mock'
require 'gri/plugin/exec_collector'

module GRI

class MockExecCollector < ExecCollector
  def popen cmd
    return MockIO.new, MockIO.new, MockIO.new
  end
end

class TestExecCollector < Test::Unit::TestCase
  def test_exec_collector
    Collector::TYPES['exec'] = MockExecCollector
    host = 'exhost'
    options = {'type'=>'exec', 'cmd'=>'vmstat 1 1|tail -1',
      'out_keys'=>'procs_r,procs_b,memory_swpd,memory_free,memory_buff'}
    records = []
    collector = Collector.create(options['type'], host, options) {|rs|
      records += rs
    }
    assert_kind_of ExecCollector, collector

    collector.on_read "0 0"
    assert records.empty?
    collector.on_read " 2000 3000\n0 0 4000 5000"
    ae 1, records.size
  end
end

end
