require 'gri/builtindefs'
require 'gri/blank'
require 'gri/request'
require 'gri/utils'
require 'gri/rrd'

module GRI
  class Graph
    include Utils

    SIZE = {'ss'=>[145, 80], 's'=>[400, 80], 'l'=>[640, 300],
      'll'=>[860, 500], 'xl'=>[1200,700], 'gf'=>[387, 110]}
    SIZE.default = [560, 120]
    SCOLORS = ['3366ff', 'ff6666', '00cc00', 'ffccff', 'ff0000', 'ffff00',
      '00ff00', '009900', '33ccff', '990000', 'cc99ff', '330099', 'ff33ff',
      '33ffff', 'ffcc33', '33cc99', 'cccccc', '9999ff', '000000', 'eeee66',
      '3f3fff', '3faf3f', 'ff3f3f', 'ffaf3f', '990033', '003399', '3fff3f',
      'ffff3f', '3f667f', '00cc00', 'ff9966', '3366cc', '666666', '99ff99']

    def initialize options={}
      @options = options
      @hprops = {}
      @hosthash = {}
    end

    def get_rrdpaths_and_ub rnames
      total_ub = 0
      rrdpaths = []
      dirs = @options[:dirs]
      for rname in rnames
        host, key = rname.split('_', 2)
        @hosthash[host] = true
        dir, h = search_records dirs, host
        if h
          @hprops[host] ||= h
          if h[key]
            prop = get_prop h[key]
            total_ub += prop[:ub].to_i
          end
          path = "#{dir}/#{host}/#{Rack::Utils.escape rname}.rrd"
          rrdpaths.push path if File.exist? path
        end
      end
      return rrdpaths, total_ub
    end

    def mk_graph_title rs, params
      if params['p'] == 't'
        r, = rs
        host, key = r.split('_', 2)
        dir, h = search_records @options[:dirs], host
        if h
          @hprops[host] ||= h
          if h[key]
            prop = get_prop h[key]
            t = %Q{"#{host} #{prop[:name]} #{prop[:description]}"}
          end
        end
      elsif (params['p'] == 's' or params['p'] == 'v') and
          (params['ds'] and params['ds'] != '')
        t = params['ds']
      end
      t
    end

    def mk_label path
      dir = File.dirname path
      label = File.basename path, '.rrd'
      host, key = label.split('_', 2)
      h = (@hprops[host] ||= (load_records "#{dir}/#{host}"))
      if h and h[key]
        prop = get_prop h[key]
        name = prop[:legend] || prop[:name] || key
        label = (@hosthash.size > 1) ? "#{host} #{name}" : name
      end
      label
    end

    def mk_graph_args specs, rrdpaths, params
      defs = []

      gidx = params['g'].to_i
      gr_spec = (specs[:graph] || [])[gidx]
      vlabel, base, limit, pickup_re, opts = gr_spec
      defs.push %Q{-v "#{vlabel.gsub(/\"/, '')}"} if vlabel
      if Numeric === base
        defs.push(base.zero? ? '--units-exponent 0 --alt-y-grid' :
                   "--base #{base}")
      end
      defs.push "--lower-limit 0"

      ds_specs = specs[:ds] || []
      ds_specs = ds_specs.grep pickup_re if pickup_re
      defs += mk_defstr ds_specs, rrdpaths, params, limit
      defs.flatten
    end

    def mk_defstr ds_specs, rrdpaths, params, limit
      mdefs = []
      ds_param = params['ds'].blank? ? nil : params['ds']
      if limit and limit.size == 2
        lower, upper = limit
      end
      x_p = (params['fmt'] == 'json')
      for ds_spec in ds_specs
        mname, dsname, dst, cf, gline, gcolor, legend, mag = ds_spec.split(',')
        next if gline == '-' or (ds_param and ds_param != dsname)
        cf = 'MAX' if cf.blank?
        gline = 'LINE1' if gline.blank?
        gcolor = '#0000ff' if gcolor.blank?
        legend = dsname if legend.blank?
        mag ||= 1
        gattr = [gline, gcolor, legend, params['cl'], params['hw']]
        sdefs = mk_comp_defs(rrdpaths, params['p'], gattr) {
          |paths, xcf, ind, gattr|
          xgline, xgcolor, xlegend = gattr
          xgline = 'XPORT' if x_p
          RRD.defstr paths, dsname, cf, "#{dsname}#{ind}",
            xgline, xgcolor, xlegend, mag, lower, upper
        }
        mdefs.push sdefs
      end
      mdefs
    end

    def mk_comp_defs rrdpaths, comp_t, gattr, &block
      case comp_t
      when 's'; mk_stack_defs rrdpaths, gattr, &block
      when 'v'; mk_ov_defs rrdpaths, gattr, &block
      else mk_sum_defs rrdpaths, gattr, &block
      end
    end

    def mk_sum_defs rrdpaths, gattr, &block
      if (legend = gattr[2]) == ':index'
        path, = rrdpaths
        host, dn, gattr[2] = File.basename(path, '.rrd').split('_', 3)
      end
      block.call(rrdpaths, 'MAX', 0, gattr)
    end

    def mk_stack_defs rrdpaths, gattr, &block
      defs = []
      gline = 'AREA'
      rrdpaths.each_with_index {|path, ind|
        gcolor = '#' + SCOLORS[ind % SCOLORS.size]
        legend = mk_label path
        gattr = [gline, gcolor, legend]
        defs += [block.call([path], 'MAX', ind, gattr)]
        gline = 'STACK'
      }
      defs
    end

    def mk_ov_defs rrdpaths, gattr, &block
      defs = []
      rrdpaths.each_with_index {|path, ind|
        gcolor = '#' + SCOLORS[ind % SCOLORS.size]
        legend = mk_label path
        gattr = ['LINE1', gcolor, legend]
        defs += [block.call([path], 'MAX', ind, gattr)]
      }
      defs
    end

    def call env
      req = GRI::Request.new env
      params = req.gparams
      ENV['TZ'] = params['tz'].to_s unless params['tz'].blank?
      stime, etime = req.params['stime'].to_i, req.params['etime'].to_i
      etime = (Time.now + etime).to_i if etime <= 0
      stime = (etime + stime).to_i if stime <= 0

      if req.params['fmt'] == 'json'
        str = xport stime, etime, params
        [200, {'Content-type'=>'text/plain'}, [str]]
      else
        img = graph stime, etime, params
        [200, {'Content-type'=>'image/png'}, [img]]
      end
    rescue
      Log.error "#{$!}: #{$@.first}"
      [500, {}, []]
    end

    def xport stime, etime, params
      rnames = params.getvar 'r'
      r = rnames.first
      host, data_name, index = parse_host_key r
      rrdpaths, total_ub = get_rrdpaths_and_ub rnames

      specs = DEFS.get_specs data_name
      gidx = params['g'].to_i
      gr_spec = (specs[:graph] || [])[gidx]
      vlabel, base, limit, pickup_re, opts = gr_spec

      ds_specs = specs[:ds] || []
      ds_specs = ds_specs.grep pickup_re if pickup_re
      args = []
      if params['maxrows'].present?
        args.push "--maxrows #{params['maxrows'].to_i}"
      end
      args += mk_defstr(ds_specs, rrdpaths, params, limit).flatten
      rrd = RRD.new Config['rrdcached-address']
      str = rrd.xport stime, etime, *args
    end

    def graph stime, etime, params
      rnames = params.getvar 'r'
      r = rnames.first
      host, data_name, index = parse_host_key r
      rrdpaths, total_ub = get_rrdpaths_and_ub rnames

      args = []
      if total_ub > 0
        args.push "-u #{total_ub} --alt-autoscale-max" if params['y'] == 'u'
        args.push "HRULE:#{total_ub}#ff0000"
      end
      if params['title']
        args.push "--title \"#{params['title']}\""
      elsif (title = mk_graph_title rnames, params)
        args.push "--title #{title}"
      end

      specs = DEFS.get_specs data_name
      args += mk_graph_args specs, rrdpaths, params

      rrd = RRD.new Config['rrdcached-address']
      # size
      rrd.width, rrd.height = SIZE[params['z']]
      # font
      if Config['font']
        Config.getvar('font').each {|fstr| rrd.fonts.push fstr}
      end

      img = rrd.graphgen stime, etime, args
    end
  end
end
