require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'rack'
require 'gri/page'

module GRI

class TestPage < Test::Unit::TestCase
  def setup
    @root_dir = File.dirname(__FILE__) + '/root'
    @page = Page.new
  end

  def test_page_mk_page_title
    rs = ['testhost__eth0']
    res = @page.mk_page_title([@root_dir + '/gra'], rs, {})
    ae 3, res.size
    ae 'testdescr', res[0]
    assert_match(/__eth0/, res[1])
    assert_match(/ eth0/, res[2])
  end

  def test_page_mk_param_str
    rs = ['r0.example.com', 'r 1?']
    params = {}
    assert_match /\br=r\+1%3F/, @page.mk_param_str(0, 0, rs, nil, params)
  end

  def test_page_mk_graph_tag
    stime = Time.local(2013,10,1)
    etime = stime + 24*3600
    rs = ['testhost__eth0']
    params = {'p'=>'s'}
    res = @page.mk_graph_tag stime, etime, rs, params
    ae 2, res.scan(/inoctet/).size
    ae 2, res.scan(/indiscard/).size
    ae 2, res.scan(/inerror/).size
  end

  def test_page_parse_request
    s = '/?r=testhost__eth0&cs=2013-10-01&ce=2013-10-02'
    env = Rack::MockRequest.env_for s
    req = GRI::Request.new env
    stime, etime, params = @page.parse_request req
    ae 1380553200, stime.to_i
    ae 1380639600, etime.to_i
    ae 'testhost__eth0', params['r']
  end
end

end
