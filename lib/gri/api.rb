require 'fileutils'
require 'gri/updater'

module GRI
  class API
    def call env
      if env['PATH_INFO'] =~ %r{^/api/(\w+)/(\w+)/(\w+)\b}
        service_name, section_name, graph_name = $1, $2, $3
        req = Rack::Request.new env
        root_dir = Config['root-dir'] || Config::ROOT_PATH
        cast_dir = root_dir + '/cast'
        service_dir = "#{cast_dir}/#{service_name}"
        host = section_name
        key = "num_#{graph_name}"
        FileUtils.mkdir_p service_dir

        records = [{'_host'=>host, '_key'=>key, 'num'=>req['number']}]
        writer = Writer.create 'rrd', :gra_dir=>service_dir, :interval=>60
        writer.write records
        writer.finalize
        res = "OK\n"
      else
        res = "NG\n"
      end
      [200, {}, [res]]
    end
  end
end
