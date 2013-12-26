require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'gri/util_marshal'

module GRI

class TestUtilMarshal < Test::Unit::TestCase
  def test_util_marshal
    obj = {'a'=>10, :a=>[nil, 1, 2]}
    path = '/tmp/test.dump'
    Marshal.dump_to_file obj, path
    newobj = Marshal.load_from_file path
    ae obj, newobj
  end
end

end
