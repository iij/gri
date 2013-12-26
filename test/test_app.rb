require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'gri/app_collector'

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

class TestApp < Test::Unit::TestCase
  def setup
    @root_dir = File.dirname(__FILE__) + '/root'
  end

  def test_app_load_target_lines
    config = Config.new
    path = File.expand_path(@root_dir + '/testtab')
    config['gritab-path'] = path
    app = AppCollector.new config
    lines = app.load_target_lines config
    assert(lines.size >= 9)

    targets = app.get_targets_from_lines lines, config
    host, options = targets.first
    ae 'localhost', host
    ae '2c', options['ver']
    ae 'public', options['community']
    assert !options['interfaces']

    config['host-pat'] = '00'
    targets = app.get_targets_from_lines lines, config
    ae 1, targets.size
    ae 'host00', targets.first.first

    config['host-pat'] = '02'
    targets = app.get_targets_from_lines lines, config
    ae 2, targets.size
    ae 'host02', targets.last.first
  end

  def test_load_fake_descr_files
    config = Config.new
    app = AppCollector.new config
    files = [@root_dir + '/if.def']
    h = app.load_fake_descr_files files
    ae 'Test eth0 Description', h['testhost']['_eth0']
  end
end

end
