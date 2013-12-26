require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'socket'
require 'mock'
require 'gri/log'
require 'gri/scheduler'
require 'gri/collector'

module GRI

class MockCollector < Collector
  TYPES['mock'] = self
end

class TestScheduler < Test::Unit::TestCase
  def setup
    loop = MockLoop.new
    metrics = Hash.new 0
    @scheduler = Scheduler.new loop, metrics
  end

  def test_scheduler_process1
    options = {}
    metrics = @scheduler.instance_eval {@metrics}
    ae 0, metrics[:run_count]
    @scheduler.process1 'mock', 'testhost', options
    ae 1, metrics[:run_count]
  end
end

end
