require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'fileutils'

require 'gri/writer'

module GRI

class Writer
  attr_reader :options
end

class TestWriter < Test::Unit::TestCase
  def test_writer
    tra_dir = '/tmp'
    writer = Writer.create 'ldb', :tra_dir=>tra_dir, :tra_expire_day=>1
    assert_kind_of TextWriter, writer

    hdir = tra_dir + '/testhost'
    FileUtils.rm_r hdir, :force=>true
    records = [{'_host'=>'testhost', '_key'=>'SYS', '_sysdescr'=>'TEST'}]
    writer.write records
    writer.finalize
    sysdir = hdir + '/SYS_'
    fname = Dir.glob(sysdir + '/*').first
    str = File.read fname
    assert_match /_sysdescr:TEST/, str
    writer.purge_logs
    FileUtils.rm_r hdir, :force=>true
  end
end

end
