require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'gri/ldb'

module GRI

class TestLDB < Test::Unit::TestCase
  def setup
    root_dir = File.expand_path(File.dirname(__FILE__) + '/root')
    dir = root_dir + "/tra/testhost"
    @ldb = LocalLDB.new dir
  end

  def test_local_ldb
    time = Time.local(2013, 6, 14, 12, 0)
    a = []
    @ldb.get_after('', time) {|t, h|
      a.push h
    }
    ae 7, a.size
  end

  def test_get_data_names
    data_names = @ldb.get_data_names
    ae [''], data_names.keys
  end
end

end
