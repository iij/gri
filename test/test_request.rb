require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'rack'
require 'gri/request'

module GRI

class TestRequest < Test::Unit::TestCase
  def test_request
    env = Rack::MockRequest.env_for '/?r=1&r=2'
    req = GRI::Request.new env
    ae({'r'=>'2'}, req.params)
    ae ['1', '2'], req.gparams.getvar('r')
  end

  def test_request_parse_query
    s = 'r=192.168.0.1__GigabitEthernet1-2&stime=-108000&z=&tz=&y=&g=0'
    res = Rack::Utils.parse_query s
    ae '192.168.0.1__GigabitEthernet1-2', res['r']
    ae '-108000', res['stime']
    ae '', res['z']
    ae '0', res['g']
  end
end

end
