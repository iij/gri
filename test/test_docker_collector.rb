require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'mock'
require 'gri/plugin/docker_collector'

module GRI

class MockDockerCollector < DockerCollector
end

class TestDockerCollector < Test::Unit::TestCase
  def _test_docker_collector
    Collector::TYPES['docker'] = MockDockerCollector

    host = 'dockerhost'
    options = {'type'=>'docker'}
    records = []
    collector = Collector.create(options['type'], host, options) {|rs|
      records += rs
    }
    assert_kind_of DockerCollector, collector

    s = '{"GitCommit":"28ff62e/0.7.9","GoVersion":"go1.2","KernelVersion":"2.6.32-999.9.abc.x86_64","Version":"0.7.9"}'
    collector.on_read s + "\n"
  end
  def test_dummy
  end
end

end
