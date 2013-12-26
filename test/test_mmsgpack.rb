require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'msgpack'
require 'gri/mmsgpack'

class TestMMsgpack < Test::Unit::TestCase
  def eq obj
    ae obj, MessagePack.unpack(obj.to_msgpack)
  end

  def test_mmsgpack
    eq 1
    eq -1
    eq 0x7fffffff
    eq 1000
    eq 2000000000
    eq 1000000000000

    eq 'abc'

    assert_nil MessagePack.unpack(nil.to_msgpack)

    eq [1,2,'a']

    eq 1=>'abc'
  end
end
