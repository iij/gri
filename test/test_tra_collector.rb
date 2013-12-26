require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'mock'
require 'gri/tra_collector'

module GRI

class MockWriter
  attr_reader :record_count
  def initialize
    @record_count = 0
  end

  def write records
    @record_count += records.size
  end
end

class TestTraCollector < Test::Unit::TestCase
  def setup
    @root_dir = File.dirname(__FILE__) + '/root'
  end

  def test_tra_collector
    config = {}
    writer = MockWriter.new
    collector = Collector.create('tra', 'testhost', {}) {|records|
      writer.write records
    }
    dir = @root_dir + '/gra/testhost'
    Dir.glob(dir + '/.lu_*') {|path| File.unlink path}
    db = LocalLDB.new "#{@root_dir}/tra/testhost"
    options = {}
    ae 0, writer.record_count
    collector.update_rrd_dir dir, db, options
    ae 20, writer.record_count
  end
end

end
