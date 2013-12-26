require 'gri/utils'
require 'gri/builtindefs'
require 'gri/format_helper'

module GRI
  class DSList
    include Utils
    include FormatHelper
    SORT_PROC = {
      :by_name=>Proc.new {|a, b|
        (cmp = a.first.to_s.gsub(/(\d+)/) {"%06d"%$1.to_i} <=>
         b.first.to_s.gsub(/(\d+)/) {"%06d"%$1.to_i}).zero? ?
        a.first <=> b.first : cmp
      }
    }

    def initialize options={}
      @options = options
    end

    def call env
      req = Rack::Request.new env
      dirs = @options[:dirs]

      list_item = env['PATH_INFO'] || ''
      host = File.basename list_item
      gra_dir, records = search_records dirs, host
      return [404, {}, ['Not Found']] unless gra_dir
      dir = gra_dir + list_item
      sysinfo = records['SYS'] || {}
      data_hash = get_data_hash records
      data_names = data_hash.keys.sort

      @title = host
      body = render(Grapher.layout) {render template, binding}
      [200, {'Content-type' => 'text/html'}, [body]]
    end

    def get_data_hash records
      h = {}
      for key, record in records
        next if !key or key == 'SYS'
        data_name, index = parse_key key
        next unless data_name
        specs = DEFS.get_specs data_name
        next unless specs and (specs[:list] or specs[:list_text])
        next if specs[:hidden?] and specs[:hidden?].call(record)
        record['_index'] = index; record[:key] = index
        if specs[:prop]
          specs[:prop].each {|k1, k2| record[k1] = record[k2] if record[k2]}
          record[:name] ||= specs[:prop][:name]
        end
        h[data_name] ||= []
        h[data_name] << [key, record, nil]
      end
      h
    end

    def format_data_list dir, data_name, items
      host = File.basename dir
      specs = DEFS.get_specs data_name
      hdstr, pat = specs[:list] || specs[:list_text]
      hds = (Array === hdstr) ? hdstr : hdstr.split(',')
      formats = (pat || '%N').split(',')

      p0 = ((hds.size == formats.size) ?
            [hds.map {|hd| td(h(hd), :head=>true)}] :
            [[td(h(hds.join('.')), :head=>true, :colspan=>formats.size)]])
      ckeys = []
      p1 = items.sort(&SORT_PROC[:by_name]).map {|key, prop|
        host_key = "#{host}_#{key}"
        href = File.exist?("#{dir}/#{host_key}.rrd") ?
        (ckeys.push key; url_to("?r=#{host_key}")) : nil
        format_tr formats, prop, :href=>href
      }
      if specs[:composite] and p1.size > 1
        links = mk_comp_links specs[:composite], host, ckeys
        p1.push [td(links.join(' | '), :colspan=>formats.size)]
      end
      p0 + p1
    end

    CMNAME = {'s'=>'stack', 'v'=>'overlay', ''=>'sum', 't'=>'tile'}
    def mk_comp_links comps, host, ckeys
      links = []
      for cm in comps
        href_fp = url_to "?p=#{cm}&"
        href = href_fp + ckeys.map {|k| "r=#{host}_#{k}"}.join('&')
        links.push mk_tag('a', {:href=>href}, CMNAME[cm])
      end
      links
    end

    def format_tr formats, prop, options={}
      formats.map {|format|
        format = format.gsub(/\\(\w)/) {
          case $1
          when 'r'; options[:class] = 'text-right'
          end
          ''
        }
        format_cell format, prop, options
      }
    end

    def format_cell f, prop, options={}
      str = f.gsub(/%([\.\/a-z\d][\.\/A-Za-z_\d]*)?([%A-Z])/) {
        case $2
        when 'D'
          prop[:description]
        when 'N'
          name = prop[:name]
          (href = options[:href]) ? "<a href=\"#{h href}\">#{h name}</a>" : name
        when 'I'
          addrs = (prop[:ipaddr] || '').split(',').map {|item|
            if item =~ %r{^(\d+\.\d+\.\d+\.\d+)/(\d+\.\d+\.\d+\.\d+)}
              ipaddr = $1
              int, = $2.split('.').map {|s|s.to_i}.pack('C4').unpack('N')
              mask = 32 - Integer(Math.log((int ^ 0xffffffff) + 1) / Math.log(2))
              ipaddr + '/' + mask.to_s
            else
              item
            end
          }.join('</br>')
        when 'L'
          if $1
            base, mag = $1.split('/')
            base = base.to_i
          end
          #mag = (mag || 1).to_f
          to_scalestr(prop[:lastvalue], base)
        when 'S'
          (prop[:astatus].to_i == 2) ? 'AdminDown' :
            ((prop[:ostatus].to_i == 2) ? 'Down' : '')
        when 'U'
          to_scalestr(prop[:ub], $1.to_i)
        else
          ''
        end
      }
      td str, :class=>options[:class]
    end

    def template
      <<'EOS'
<span class="large"><%=h host %></span>
<small><%=h sysinfo['_sysdescr'] || '' %></small><br/>
<hr/>

<table>
<% for data_name in data_names -%>
<tr><td>
<table class="table ds" width="100%">
<% for row in format_data_list dir, data_name, data_hash[data_name] -%>
  <tr>
    <%= row.join('') %>
  </tr>
<% end -%>
</table>
</td></tr>
<% end -%>
</table>
EOS
    end
  end
end
