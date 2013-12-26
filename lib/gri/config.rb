module GRI
  class Config
    ROOT_PATH = '/usr/local/gri'
    DEFAULT_PATH = ROOT_PATH + '/gri.conf'

    def initialize
      @h = {}
    end

    def setvar key, value
      @h[key] = (Array === value) ? value : [value]
    end

    def getvar key
      @h[key]
    end

    def []=(key, value)
      (@h[key] ||= []).push value
    end

    def [](key)
      (Array === (v = @h[key])) ? v.last : v
    end

    def keys
      @h.keys
    end

    def has_key? key
      @h.has_key? key
    end

    def to_h
      @h.inject({}) {|h, item|
        k, v = item
        h[k] = (item.last.size > 1) ? v : v.first
        h
      }
    end

    def self.load_from_file path
      conf = self.new
      if File.exist? path
        File.open(path) {|f|
          while line = f.gets
            line.chomp!
            next if line =~ /^\s*(#|$)/
            if line =~ /^\s*(\S+)\s+(.*)/
              key, value = $1, $2
              conf[key] = value
            end
          end
        }
      end
      conf
    end

    def self.init path=nil
      @config = path ? load_from_file(path) : new
    end

    def self.setvar key, value
      @config.setvar key, value
    end

    def self.getvar key
      @config.getvar key
    end

    def self.[]=(key, value)
      @config[key] = value
    end

    def self.[](key)
      @config[key]
    end

    def self.keys
      @config.keys
    end

    def self.has_key? key
      @config.has_key? key
    end

    def self.parse_options(*strs)
      options = {}
      for s in strs
        next unless s
        for var, value in s.scan(/([^=\s]+)(?:=((?:`[^`]+`)|(?:"[^"]+")|\S+))?/)
          if value
            if value =~ /^[`"]([^`"]+)[`"]/
              value = $1
            end
            options[var] = value
          else
            if var =~ /^no-/
              options[$~.post_match] = false
            else
              options[var] = var
            end
          end
        end
      end
      options
    end

    def self.option_if_match matchstr, varname, config
      h = {}
      if (varlines = config.getvar varname)
        for line in varlines
          pat, *optstr = line.split
          if matchstr =~ Regexp.new(pat)
            h.merge!(parse_options(*optstr))
          end
        end
      end
      h
    end

    def self.get_targets_from_lines lines
      targets = []
      for line in lines
        if line =~ /^\s*(\w\S*)(?:\s+(.*))?/
          host, remain = $1, $2
          options = parse_options remain
          targets.push [host, options]
        end
      end
      targets
    end
  end
end
