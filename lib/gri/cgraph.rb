require 'gri/rrd'
require 'gri/graph'

module GRI
  class Cgraph
    TERMS = {'sh'=>['Hour', 3600], 's8h'=>['8Hours', 8*3600],
      'd'=>['Day', 24*3600], 'w'=>['Week', 7*24*3600],
      'm'=>['Month', 31*24*3600], 'y'=>['Year', 366*24*3600]}

    def initialize options={}
      @options = options
    end

    def call env
      req = Rack::Request.new env
      service_name, section_name, graph_name = Cast.parse_path_info env

      begin
        cast_dir = @options[:dir]
        gra_dir = "#{cast_dir}/#{service_name}"

        params = GParams.new
        params['r'] = "#{section_name}_num_#{graph_name}"
        params['z'] = 'gf'
        t = req.params['t'] || 'd'
        params['title'] = TERMS[t].first
        gr = Graph.new :dirs=>[gra_dir]
        etime = Time.now.to_i
        stime = etime - TERMS[t][1]
        img = gr.graph stime, etime, params
        [200, {'Content-type' => 'image/png'}, [img]]
      rescue
        [500, {}, []]
      end
    end
  end
end
