require 'gri/builtindefs'
require 'gri/config'
require 'gri/log'
require 'gri/utils'
require 'gri/wmain'
require 'gri/request'
require 'gri/list'
require 'gri/ds_list'
require 'gri/page'
require 'gri/graph'

module GRI
  class Grapher
    def initialize
      root_dir = Config['root-dir'] ||= Config::ROOT_PATH
      log_dir = Config['log-dir'] || Config['root-dir'] + '/log'
      Log.init "#{log_dir}/#{File.basename $0}.log"
    rescue SystemCallError
      Log.init '/tmp/grapher.log'
    end

    def call env
      req = GRI::Request.new env
      params = req.params

      gra_dirs = Config.getvar('gra-dir') || [Config::ROOT_PATH + '/gra']
      if (req.query_string =~ /\A(\d+),(\d+)\z/)
        app = Page.new :dirs=>gra_dirs, :clicked=>true, :imgx=>$1, :imgy=>$2
      elsif params['r'] or params['tag']
        if params['stime']
          app = Graph.new :dirs=>gra_dirs
        else
          app = Page.new :dirs=>gra_dirs
        end
      elsif req.path_info =~ %r{^/([-\w][-#\.\w]*)}
        app = DSList.new :dirs=>gra_dirs
      else
        app = List.new :dirs=>gra_dirs, :list_format=>Config['list-format'],
          :use_regexp_search=>Config['use-regexp-search']
      end
      app.call env
    end

    def public_dir
      File.dirname(__FILE__) + '/../../public'
    end

    def self.layout
      <<EOS
<html>
<head>
<title><%= @title %></title>
<style>
td.text-right {text-align:right;}
span.large {font-size: x-large;}
table.ds td {padding:0;background:#f9f9f9;}
table.ds th {background:#ffd0d0;
background:linear-gradient(to bottom, #ffd8d8 0%,#ffcccc 45%,#ffc0c0 100%);
text-align:left;}
hr {border:none;border-top:1px #cccccc solid;}
</style>
</head>
<body>
<%= yield %>
</body>
</html>
EOS
    end
  end
end
