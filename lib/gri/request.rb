require 'rack/request'
require 'gri/gparams'

module GRI
  class Request < Rack::Request
    def query_string=(s)
      @query_string = s
      @gparams = @params = nil
    end

    alias query_string0 query_string
    def query_string
      @query_string || query_string0
    end

    def gparams
      @gparams ||= gparse_query query_string
    end

    def gparse_query qs
      params = GParams.new
      (qs || '').split(/[&;] */n).each {|item|
        k, v = item.split('=', 2).map {|s| Rack::Utils.unescape s}
        params[k] = v
      }
      params
    end
  end
end
