require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'gri/utils'

module GRI

class TestUtils < Test::Unit::TestCase
  def test_key_encode
    s = '1/1'
    r = GRI::Utils.key_encode s
    ae '1-1', r
  end
end

end
