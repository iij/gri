require 'gri/utils'
require 'gri/format_helper'
require 'gri/blank'

module GRI
  class List
    include FormatHelper
    include Utils

    SORT_PROC = {
      'a'=>proc {|aa, bb| a, = aa; b, = bb
        (a =~ /\A[\.\d]+$/ and b =~ /\A[\.\d]+$/) ?
        ipstr2bin(a) <=> ipstr2bin(b) : a <=> b
      },
      'l'=>proc {|a, b|
        (a[1]['sysLocation'] || "\377") <=> (b[1]['sysLocation'] || "\377")
      },
      'u'=>Proc.new {|a, b|
        (a[1]['sysUpTime'].to_i) <=> (b[1]['sysUpTime'].to_i)
      },
      'v'=>Proc.new {|a, b|
        (a[1]['_ver'] || "\377") <=> (b[1]['_ver'] || "\377")
      }
    }

    def self.ipstr2bin str
      str.split('.').map {|s|s.to_i}.pack('C4')
    end

    def initialize options={}
      @options = options
      @urs = !!(options[:use_regexp_search])
    end

    def call env
      req = Rack::Request.new env
      params = req.params

      dirs = @options[:dirs]
      sysdb = load_sysdb(dirs) rescue {}

      if params['op'] == 'comp'
        shash = {}
        grep_results = grep_graph dirs, sysdb.keys, params
        for h0 in grep_results.keys.sort
          for data_name, host, key in grep_results[h0]
            (shash[data_name] ||= []).push "#{host}_#{key}"
          end
        end
        if shash.keys.size == 0
          url = url_to ''
        else
          key, = shash.keys
          rstr = shash[key].map {|hkey| "r=#{hkey}"}.join('&')
          query = "?p=#{params['p']}&s=#{key}&#{rstr}"
          url = url_to query
        end
        return [302, {'Location'=>url}, []]
      end

      ly_ary = [['0', 'none'],
        ['1', 'day'], ['7', 'week'], ['31', 'month'], ['366', 'year']]
      (ly_ary.assoc(params['ly']) || ly_ary[0])[2] = true
      sort_ary = [['a', 'hostname'], #['n','sysName'],
        ['l','location'], ['u','uptime'], ['v','version']]
      (sort_ary.assoc(params['sort']) || sort_ary[0])[2] = true

      @title = 'list'
      body = render(Grapher.layout) {render template, binding}
      [200, {'Content-type' => 'text/html'}, [body]]
    end

    def load_sysdb dirs
      sysdb = {}
      for dir in dirs
        values = LTSV.load_from_file(dir + '/.sysdb/sysdb.txt')
        values.inject(sysdb) {|h, v| h[v['_host']] = v; h}
      end
      sysdb
    end

    def sysdb_list dirs, sysdb, params
      hosts = sysdb.keys
      if params['n'].present? or params['d'].present?
        grep_results = grep_graph dirs, hosts, params
      end
      grep_results ||= {}

      sort_proc = SORT_PROC[params['sort']] || SORT_PROC['a']
      hlines = []
      for host, sysinfo in sysdb.sort(&sort_proc)
        next if params['h'].present? and host !~ mk_regexp(params['h'])
        next if sysinfo['sysDescr'] and params['sysdescr'] and
          sysinfo['sysDescr'] !~ mk_regexp(params['sysdescr'])
        line = format_rowstr host, sysinfo
        hlines.push [host, line, grep_results[host]]
      end
      hlines
    end

    def mk_regexp str
      str = @urs ? str.to_s.gsub(/[#]/) {|c| "\\#{c}"} : Regexp.quote(str.to_s)
      Regexp.new str, Regexp::IGNORECASE
    end

    def grep_graph dirs, hosts, params
      re_name = mk_regexp params['n']
      re_descr = mk_regexp params['d']
      re_host = mk_regexp params['h']
      hostres = {}
      for host in hosts
        next if params['h'].present? and host !~ re_host
        dir, h = search_records dirs, host
        if h
          for key in h.keys.sort
            prop = get_prop h[key]
            next unless re_name === prop[:name]
            next unless re_descr === (descr = prop[:description] || '')
            data_name, index = parse_key key
            (hostres[host] ||= []).push [data_name, host, key,
              prop[:name], prop[:description]]
          end
        end
      end
      hostres
    end

    def format_rowstr basename, sysinfo
      mtime = sysinfo['_mtime'].to_i
      now = Time.now.to_i
      if mtime < (now - 24*3600)
        hostname = "(#{basename})"
      else
        hostname = basename
      end
      list_format = @options[:list_format] || "%-28_H%-18M %-18V %L"
      rowstr = list_format.gsub(/(%([-+]?([ \d]+)?(\.\d+)?))(_)?([A-Z%])/) {
        form = $1 + 's'
        linkflag = $5
        case $6
        when 'H'
          s = form % hostname
        when 'L'
          s = form % sysinfo['sysLocation']
        when 'M'
          s = form % sysinfo['_firm']
        when 'N'
          s = form % sysinfo['sysName']
        when 'S'
          mtime = sysinfo['_mtime'].to_i
          if mtime > (now - 3600)
            s = Time.at(mtime).strftime '%H:%M'
          else
            s = '?'
          end
          s = form % s
        when 'U'
          if mtime > (now - 24*3600)
            ustr = ''#format_uptime sysinfo['sysUpTime']
          else
            ustr = ''
          end
          s = form % ustr
        when 'V'
          s = form % sysinfo['_ver']
        else
          s = ''
        end
        if linkflag == '_'
          ss = s.strip
          s = "<a href=\"#{h url_to(basename)}\">#{h ss}</a>" +
            ' ' * (s.size - ss.size)
        end
        s
      }

      rowstr
    end

    def template
      <<'EOS'
<% if sysdb -%>

<% if params['search'] == '1' -%>
<form enctype="application/x-www-form-urlencoded" method="get"
    action="<%=h url_to '' %>">
<table>
  <% for hname, vname in [['Hostname', 'h'], #['sysName', 'sysname'],
      ['sysDescr', 'sysdescr'], ['I/F or Name', 'n'], ['Description', 'd'],] -%>
    <tr>
      <td class=text-right><%= hname %> :</td>
      <td><%= text_field vname, params[vname], 40 %></td>
    </tr>
  <% end -%>
    <tr>
      <td class=text-right>sort by:</td>
      <td><%= popup_menu 'sort', 'form-control', *sort_ary %></td>
    </tr>
    <tr>
      <td class=text-right>graph:</td>
      <td><%= popup_menu 'ly', 'form-control', *ly_ary %></td>
    </tr>
</table>
<input type="hidden" name="start" value="<%=h params['start'] %>">
<input type="hidden" name="search" value="1">
<input class="btn btn-primary btn-sm" type="submit" value="submit">
</form>

<% if params['n'].present? or params['d'].present? -%>
<% ary = [['', 'sum'], ['s', 'stack'], ['v', 'overlay']] -%>
<% while item = ary.shift -%>
<% q = mk_query :op=>'comp', :p=>item[0], :h=>params['h'], :n=>params['n'],
         :d=>params['d'], :sysdescr=>params['sysdescr'] -%>
<a href="<%=h url_to q %>"><%= item[1] %></a>
<% if ary.size > 0 then %> | <% end -%>
<% end -%>
<% end -%>

<% else -%>
<a href="<%= url_to '?search=1'%>">Search</a>
<% end -%>

<pre>
<% for host, line, gres in sysdb_list dirs, sysdb, params -%>
<span class="line"><%= line %></span>
<% if gres -%>
<% for data_name, h2, key, name, description in gres -%>
<% url = "?r=#{h2}_#{key}" + (params['grp'] ? "&grp=#{params['grp']}" : "") -%>
 - <a href="<%=h url_to(url) %>"><%=h name %></a> <%= description %>
<% unless (ly = params['ly'].to_i).zero? -%>
<img src="<%=h url%>&z=s&stime=-<%= ly * 24 * 3600 %>"/><br/>
<% end -%>
<% end -%>
<% end -%>
<% end -%>
</pre>

<% end -%>
EOS
    end
  end
end
