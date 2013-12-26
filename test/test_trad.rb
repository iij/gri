require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'rack'
require 'gri/trad'

module GRI

class TestTrad < Test::Unit::TestCase
  def setup
    Config.init
    test_root = File.expand_path(File.dirname(__FILE__) + '/root')
    Config['tra-dir'] = test_root + '/tra'
    Config['gritab-path'] = test_root + '/testtab'
    @trad = Trad.new
    Rack::MockRequest::DEFAULT_ENV['REMOTE_ADDR'] = '127.0.0.1'
    @app = Rack::MockRequest.new @trad
  end

  def test_trad_get
    res = @app.get '/get?h=testhost&s=&t=1371178800'
    ae 200, res.status
    a = res.body.scan(/ifInOctets:(\d+)/)
    ae a.first.first, '27497623151'
    ae a.last.first, '27498895868'
  end

  def test_trad_gritab
    res = @app.get '/gritab'
    assert_match /\Alocalhost\s/, res.body.split(/\n/).first
  end
end

end
