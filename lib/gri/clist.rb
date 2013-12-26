require 'gri/format_helper'
require 'gri/util_marshal'

module GRI
  class Clist
    TERMS = {'sh'=>[['sh', 's8h'], 'hour/8hours', 0],
      'd'=>[['d', 'w'], 'day/week', 3],
      'm'=>[['m', 'y'], 'month/year', 4]}

    include FormatHelper

    def initialize options={}
      @options = options
    end

    def call env
      req = Rack::Request.new env
      if (path_info = env['PATH_INFO']) =~ %r{^/list}
        path_info = Regexp.last_match.post_match
      end
      if path_info
        dummy, service_name, section_name, graph_name = path_info.split /\// #/
      end

      list_item = path_info
      dir = @options[:dir] || Config['cast-dir'] ||
        (Config::ROOT_PATH + '/cast')

      pt = req.params['t'] || 'd'
      t = TERMS[pt] || TERMS['d']
      dirs = scan_dir dir, service_name, section_name, graph_name
      @title = 'list'
      body = render(Cast.layout) {render template, binding}
      [200, {'Content-type' => 'text/html'}, body]
    end

    def scan_dir dir, service_name, section_name, graph_name
      h = {}
      for f0 in Dir.glob(dir + '/' + (service_name || '*'))
        b0 = File.basename f0
        if File.directory? f0
          h[b0] = {}
          for f1 in Dir.glob(f0 + '/' + (section_name || '*'))
            b1 = File.basename f1
            if File.directory? f1
              h[b0][b1] = {}
              pat = graph_name ? "#{section_name}_num_#{graph_name}.rrd" : '*'
              for f2 in Dir.glob(f1 + '/' + pat)
                b2 = File.basename f2
                if b2  =~ /^(?:[^_]+)_(?:[^_]+)_(.+).rrd/
                  h[b0][b1][$1] = true
                end
              end
            end
          end
        else
          h[b0] = true
        end
      end
      h
    end

    def sysdb_path dir
      sysdb_path = dir + '/.sysdb/sysdb.dump'
    end

    def load_sysdb dir
      sysdb = Marshal.load_from_file sysdb_path(dir) || {}
    end

    def mk_graph_tag service_name, section_name, graph_name, t, ind
      cs = (Time.now - Cgraph::TERMS[t[0][ind]][1]).strftime('%Y-%m-%d %H:%M:%S')
      u = "?grp=#{service_name}&r=#{section_name}_num_#{graph_name}&pt=s"
      gu = "graph/#{service_name}/#{section_name}/#{graph_name}"
      img = "<img src=\"#{url_to gu + '?t=' + t[0][ind]}\"/>"
      "<a href=\"#{u}&cs=#{Rack::Utils.escape cs}\">#{img}</a>"
    end

    CMNAME = {'s'=>'stack', 'v'=>'overlay', ''=>'sum', 't'=>'tile'}
    def mk_comp_links comps, host, ckeys, aparam
      links = []
      for cm in comps
        href_fp = url_to "?p=#{cm}&#{aparam}"
        href = href_fp + ckeys.map {|k| "r=#{host}_#{k}"}.join('&')
        links.push mk_tag('a', {:href=>href}, CMNAME[cm])
      end
      links
    end

    def template
      <<'EOS'
<% if section_name -%>

<% d0 = dirs.keys.first -%>

<% if (ckeys = dirs[d0][section_name].keys.map {|k| "num_#{k}"}).size > 1 -%>
<div style="float: right!important;" class="pull-right"><ul class="pagination">
<% for u in mk_comp_links(DEFS['num'][:composite], section_name, ckeys, "grp=#{d0}&") -%>
<li><%= u %></li>
<% end -%>
</ul></div>
<% end -%>

<div style="float: right!important;" class="pull-right"><ul class="pagination">
<% for k, v in TERMS.sort_by {|kk, vv| vv[2]} -%>
  <li style="display: inline"<%= (pt == k) ? " class=active" : '' %>>
  <a href="<%= url_to "list/#{d0}/#{section_name}?t=#{k}" %>"><%= v[1] %></a>
  </li>
<% end -%>
</ul></div>


<section>
<h1>
<a href="<%= url_to ''%>">Home</a> &raquo;
 <a href="<%= url_to "list/#{d0}"%>"><%= d0 %></a> &raquo;
<% if graph_name -%>
 <a href="<%= url_to "list/#{d0}/#{section_name}"%>"><%= section_name%></a> &raquo;
 <%= graph_name %>
<% else -%>
 <%= section_name%>
<% end -%>
</h1>

<% for graph_name in dirs[d0][section_name].keys.sort -%>
<h2>
<a href="<%= url_to "list/#{d0}/#{section_name}/#{graph_name}"%>"><%= graph_name %></a>
</h2>
<%= mk_graph_tag service_name, section_name, graph_name, t, 0 %>
<%= mk_graph_tag service_name, section_name, graph_name, t, 1 %>
<% end %>
</section>

<% else -%><!-- if section_name -->

<section>
<h1>
<a href="<%= url_to ''%>">Home</a>
<% if service_name -%>
 &raquo; <%= service_name %>
<% end -%>
</h1>

<% for d0 in dirs.keys.sort %>
<h2><a href="<%= url_to('list') + '/' + d0 %>"><%=h d0 %>
</a></h2>
<!--a href="<%= url_to "?search=1&grp=#{d0}" %>">search</a-->
<table class="table table-striped">
<% for d1 in dirs[d0].keys.sort -%>
<tr>
  <td><a href="<%= url_to('list')+'/'+d0+'/'+d1 %>"><%= d1 %></a></td>
</tr>
<% end -%>
</table>
</section>
<% end %>

<% end -%><!-- if section_name -->
<hr/>
EOS
    end
  end
end
