require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'gri/loop'
require 'gri/collector'

module GRI

class TestLoop < Test::Unit::TestCase
  def setup
    @loop = Loop.new
  end

  def test_loop_attach_detach
    collector = GRI::Collector.new('testhost', {}, {})
    detached = false
    @loop.on_detach {detached = true}

    @loop.attach collector
    ae 1, @loop.collectors.size
    io = Object.new
    @loop.watch io, :r, 5, collector
    @loop.watch io, :w, 5, collector
    @loop.watch io, :rw, 5, collector
    @loop.detach collector
    ae 0, @loop.collectors.size
    assert detached
  end

  def test_loop_has_active_watchers
    assert !@loop.has_active_watchers?
    @loop.run
  end
end

end
