require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'gri/ltsv'

module GRI

class TestLTSV < Test::Unit::TestCase
  def test_ltsv_escape
    ae 'a\tb', LTSV.escape("a\tb")
    ae 'a\n\r\tb', LTSV.escape("a\n\r\tb")
  end

  def test_ltsv_serialize
    value = {'a'=>'1', 'b'=>'2', 'zzz'=>'10'}
    line = LTSV.serialize value
    ae value, LTSV.parse_string(line)
  end

  def test_ltsv_dump_to_file
    path = '/var/tmp/ltsv_test.txt'
    values = [{'a'=>'1', 'b'=>'2'}, {'x'=>'10', 'y'=>'20'}]
    LTSV.dump_to_file values, path
    vs = LTSV.load_from_file path
    ae values, vs
    File.unlink path
  end

  def test_parse_string
    line = "a:b\tb:1\tc:\td:"
    h = LTSV.parse_string line
    ae 'b', h['a']
    ae '1', h['b']
    assert_nil h['c']
    assert_nil h['d']
  end
end

end
