require 'time'
require 'gri/builtindefs'
require 'gri/utils'
require 'gri/request'
require 'gri/format_helper'

module GRI
  class Page
    include Utils
    include FormatHelper

    def initialize options={}
      @options = options
    end

    def mk_page_title dirs, rs, params
      jstr = (params['p'] == 't' or params['p'] == 'v') ? ', ' : ' + '
      hosthash = {}
      descrs = []
      headlegend = nil

      for rname in rs
        host, key = rname.split('_', 2)
        hosthash[host] = true
        dir, records = search_records dirs, host
        if records and (prop = get_prop records[key])
          xhost = prop[:description] ? nil : host
          descr = (prop[:description] || prop[:name] || '?').to_s
          url = if params['grp'].blank?
                  url_to("?r=#{rname}")
                else
                  url_to("?grp=#{params['grp']}&r=#{rname}")
                end
          descrs.push [url, xhost, descr]
          unless headlegend or params['grp']
            ub = prop[:ub]
            if descr or ub
              name = prop[:name].to_s
              url = url_to("#{host}")
              headlegend = "<a href=\"#{h url}\">#{h host}</a>"
              headlegend << ' ' + name if descr
              #headlegend << ", MAX: #{to_scalestr ub, 1000}"
            end
          end
        end
      end

      html_title = descrs.map {|url, xhost, descr|
        if xhost and hosthash.size > 1
          xhost + ':' + descr
        else
          descr
        end
      }.join(jstr)
      body_title = descrs.collect {|url, xhost, descr|
        if xhost and hosthash.size > 1
          "<a href=\"#{h url}\">#{h xhost}:#{h descr}</a>"
        else
          "<a href=\"#{h url}\">#{h descr}</a>"
        end
      }.join(jstr)

      return html_title, body_title, headlegend
    end

    def mk_param_str stime, etime, rs, ds, params
      res = rs.map {|r| "r=#{u r}"}
      res << "grp=#{u params['grp']}" if params['grp']
      res << "stime=#{stime.to_i}"
      res << "etime=#{etime.to_i}" if etime.to_i.nonzero?
      res << "z=#{u params['z']}"
      res << "tz=#{u params['tz']}"
      res << "y=#{u params['y']}"
      res << "p=#{u params['p']}" if params['p']
      res << "ds=#{ds}" if ds
      res.join('&')
    end

    def mk_graph_tag stime, etime, rs, params
      if params['p'] == 't'
        rs.map {|rname|
          mk_graph_tag_r stime, etime, [rname], params
        }.join("\n")
      else
        mk_graph_tag_r stime, etime, rs, params
      end
    end

    def mk_graph_tag_r stime, etime, rs, params
      specs = DEFS.get_specs @data_name
      if (gr_specs = specs[:graph]) and gr_specs.size >= 1
        if params['p'] == 's' or params['p'] == 'v'
          (0..gr_specs.size-1).map {|gidx|
            gr_spec = gr_specs[gidx]
            pickup_re = gr_spec[3]
            dss = specs[:ds] || []
            dss = dss.grep pickup_re if pickup_re
            dss = dss.map {|ds| ds.split(',', 3)[1]}
            dss.map {|ds|
              param_str = mk_param_str stime, etime, rs, ds, params
              mk_graph_tag_s param_str, gidx
            }.join ''
          }.join ''
        else
          param_str = mk_param_str stime, etime, rs, nil, params
          (0..gr_specs.size-1).map {|gidx|
            mk_graph_tag_s param_str, gidx}.join ''
        end
      end
    end

    def mk_graph_tag_s param_str, gidx=nil
      param_str += "&g=#{gidx}" if gidx
      name = ENV['SCRIPT_NAME'] || ''
      "<a href=\"#{name}/#{h param_str}\">" +
        "<img ismap src=\"#{name}?#{h param_str}\"></a><br/>"
    end

    def parse_tstr tstr
      (tstr and !tstr.empty?) ? Time.parse(tstr) : nil
    end

    def parse_request req
      now = Time.now
      if @options[:clicked]
        s = req.path_info[1..-1]
        req.query_string = s
        params = req.gparams
        z = params['z']
        width, = GRI::Graph::SIZE[z]

        canvas_x_offset = (Config['canvas-x-offset'] || 75).to_i
        imgx = @options[:imgx].to_i - canvas_x_offset
        imgy = @options[:imgy].to_i

        stime = params['stime'].to_i
        etime = params['etime'].to_i
        etime = (now + etime).to_i if etime <= 0
        stime = (etime + stime).to_i if stime <= 0
        stime = Time.at stime
        time = stime + ((Time.at(etime) - stime) / width) * imgx
        stime = Time.local(time.year, time.mon, time.day)
        etime = stime + 24*3600
        params['pt'] = 's'
      else
        params = req.gparams
        deftime = now - now.to_i % 60
        stime = parse_tstr(params['cs']) || deftime - 7*24*3600
        etime = parse_tstr(params['ce']) || deftime
      end
      return stime, etime, params
    end

    def call env
      req = GRI::Request.new env
      ENV['TZ'] = req.params['tz'].to_s unless req.params['tz'].blank?
      stime, etime, params = parse_request req

      cs = stime.strftime '%Y-%m-%d %H:%M:%S'
      ce = etime.strftime '%Y-%m-%d %H:%M:%S'

      r = params['r'] || ''
      host, @data_name, index = parse_host_key r
      rs = params.getvar 'r'

      @title, body_title, headlegend =
        mk_page_title @options[:dirs], rs, params

      defs_term = DEFS[:term]
      sym = params['tm'].blank? ? '' : params['tm'].intern
      terms = defs_term[sym] || defs_term[:default]
      body = render(Grapher.layout) {render template, binding}
      [200, {'Content-type' => 'text/html'}, [body]]
    end

    TZS = [['', 'localtime'], ['JST-9', 'JST-9'],
      ['EST5EDT', 'EST5EDT'], ['PST8PDT', 'PST8PDT'],
      ['Europe/London', 'Europe/London'],
      ['Europe/Amsterdam', 'Europe/Amsterdam'],
      ['Singapore', 'Singapore']]
    def template
      <<'EOS'
<span class="large"><%= body_title %></span><br/>
<% if params['z'] != 'll' and rs.size == 1 and headlegend and headlegend.size > 0 -%>
<span class="small"><%= headlegend %></span><br/>
<% end -%>
<br/>

<form enctype="application/x-www-form-urlencoded" method="get"
 action="<%= url_to '?' %>">
<% rs.each {|r| -%><%= hidden 'r', r %><% } -%>
<% if params['grp'] then %><%= hidden 'grp', params['grp'] %><% end %>
<% tzs = TZS -%>
<% (tzs.assoc(params['tz']) || tzs[0])[2] = true -%>
TIMEZONE: <%= popup_menu('tz', nil, *tzs) %>
<% nflag, uflag = (params['y'] == 'u') ? [false, true] : [true, false] -%>
Y-axis scale:
<%= radio_button 'y', 'a', nflag %>auto
<%= radio_button 'y', 'u', uflag %>upper limit<br/>
<%= check_box 'pt', 's', (params['pt'] == 's') %>
<nobr>
from <%= text_field 'cs', cs, 20, 19, nil %>
to <%= text_field 'ce', ce, 20, 19, nil %>
</nobr>
<% zs = [['ss', 'SS'], ['s', 'S'], ['m', 'M'], ['l', 'L'], ['ll', 'LL']] -%>
<% (zs.assoc(params['z']) || zs[2])[2] = true -%>
Graph size: <%= popup_menu('z', nil, *zs) %>
<% tms = defs_term.sort_by {|k, v| v[0][1]}.map {|k,| [k.to_s, k.to_s]} -%>
<% (tms.assoc(params['tm']) || tms[1])[2] = true -%>
term: <%= popup_menu('tm', nil, *tms) %>
<br/>
<% if rs.size > 1 -%>
<% c_ary = [['', 'sum'], ['s', 'stack'], ['v', 'overlay'], ['t', 'tile']] -%>
<% (c_ary.assoc(params['p']) || c_ary[0])[2] = true -%>
Composite type: <%= popup_menu('p', nil, *c_ary) %><br/>
<% end -%>
<input class="btn btn-primary btn-sm" type="submit" value="submit">
</form>

<% if params['pt'] == 's' -%>
<%= mk_graph_tag stime.to_i, etime.to_i, rs, params %>
<% else -%>
<% for label, int in terms -%>
<hr/><p>
<strong><%=h label %> Graph</strong><br/>
<%= mk_graph_tag -int, 0, rs, params %>
</p>
<% end -%>
<% end -%>

<hr/><!--%= RUBY_VERSION %-->
EOS
    end
  end
end
