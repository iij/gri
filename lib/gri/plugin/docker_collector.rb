if Object.const_defined? :RUBY_VERSION

#GRI::DEFS.update 'docker'=>{
#    :ds=>['inbytes.0,inoctet,DERIVE,MAX,AREA,#90f090,in,8',
#      'outbytes.0,outoctet,DERIVE,MAX,LINE1,#0000ff,out,8',
#    ],
#    :list=>['Docker'],
#    :prop=>{:name=>'_index'},
#    :graph=>[['bps', 1000, [0, nil], /octet/]],
#}

begin

require 'net/http'
require 'json'
require 'gri/collector'

module GRI
  class DockerCollector < Collector
    TYPES['docker'] = self

    def on_attach
      now_i = Time.now.to_i

      records = []
      host = @hostname || @host
      port = @options["docker-port"] || 2375
      port = port.to_i

      puts "docker: #{host}:#{port}" if $debug
      Net::HTTP.start(host, port) {|http|
        res = http.get '/info'
        if Net::HTTPSuccess === res
          h = JSON.parse(res.body)
          for k in ['Containers', 'Images',
              'NEventsListener', 'NFd', 'NGoroutines']
            record = {'_host'=>host, '_time'=>now_i, '_interval'=>@interval,
              '_key'=>"num_docker_#{k}", 'num'=>h[k],
            }
            records.push record
          end
        end

        res = http.get '/containers/json'
        if Net::HTTPSuccess === res
          a = JSON.parse(res.body)
          for c in a
            if (cinfo = get_container_info(http, c['Id']))
              docker_hostname = cinfo['Config']['Hostname']
              docker_image = cinfo['Config']['Image']
              metrics = cinfo['Metrics']
              record = {'_host'=>host, '_time'=>now_i, '_interval'=>@interval,
                '_key'=>"docker_#{docker_hostname}"
              }
              for mkey, mvalues in metrics
                if mkey == 'memory' or mkey == 'cpuacct'
                  h = hflat mvalues
                else
                  h = mvalues
                end
                for k, v in h
                  record[k] = v
                end
              end
              records.push record
            end
          end
        end
      }

      @cb.call records
      @loop.detach self
    end

    def hflat h
      hh = {}
      for k, v in h
        if Hash === v
          hh.update hflat(v)
        elsif Array === v
          v.each_with_index {|vv, ind|
            hh["#{k}.#{ind}"] = vv
          }
        else
          hh[k] = v
        end
      end
      hh
    end

    def get_container_info http, ctn_id
      if Net::HTTPSuccess === (res = http.get "/containers/#{ctn_id}/json")
        h = JSON.parse(res.body)
        return h if h and h['Metrics']
      end
      nil
    end
  end
end

rescue LoadError
end

end
