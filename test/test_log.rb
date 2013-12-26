require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'gri/log'

module GRI

class TestLog < Test::Unit::TestCase
  def test_log
    time = Time.local(2014,1,2,3,4,56)
    formatter = Log::Formatter.new
    s = formatter.call nil, time, nil, 'test message'
    ae "2014-01-02 03:04:56 test message\n", s
  end
end

end
