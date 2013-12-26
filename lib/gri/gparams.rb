module GRI
  class GParams
    include Enumerable

    def initialize
      @params = {}
    end

    def setvar key, value
      @params[key] = value
    end

    def getvar key
      @params[key]
    end

    def []=(key, value)
      (@params[key] ||= []).push value
    end

    def [](key)
      (Array === (v = @params[key])) ? v.last : v
    end

    def each
      @params.each {|k, v| yield k, v}
    end

    def update hash
      hash.each {|key, value|
        @params[key] = [value]
      }
    end

    def merge cgi_params
      for key, values in cgi_params
        for value in values
          self[key] = value
        end
      end
    end
  end
end
