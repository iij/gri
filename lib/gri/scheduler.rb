module GRI
  class Scheduler
    attr_accessor :queue, :writers, :fake_descr_hash

    def initialize loop, metrics
      @loop = loop
      @metrics = metrics
      @loop.on_detach {process_queue}
      @writers = []
    end

    def process_queue
      while @loop.collectors.size < 5
        host, options = queue.shift
        break unless host
        next if host =~ /^GRIMETRICS/

        ts = options['type']
        col_types = ts ? ts.split(',') : ['snmp']
        for col_type in col_types
          process1 col_type, host, options
        end
      end
    end

    def process1 col_type, host, options
      return if Config['nop']
      return if col_type == 'fluentd'
      collector = Collector.create(col_type, host, options,
                                   @fake_descr_hash) {|records|
        for writer in @writers
          puts "  writer #{writer.class}" if $debug
          writer.write records
        end
        @metrics[:record_count] += records.size
      }
      if collector
        #puts "#{collector.class} (#{col_type}): #{host}" if $debug
        interval = (options['interval'] || 300).to_i
        collector.interval = interval
        timeout = (options['timeout'] || Config['timeout'] || 90).to_i
        collector.timeout = [timeout, interval].min
        collector.on_error {@metrics[:error_count] += 1}
        collector.on_retry {@metrics[:retry_count] += 1}
        Log.info "[#{$$}] #{host}: collect #{col_type}"
        begin
          @loop.run if collector.sync?
          @loop.attach collector
        rescue SystemCallError
          Log.error "#{host}: ERROR: #{$!}"
          puts "#{host}: ERROR: #{$!}" if $debug
          @loop.detach collector
        end
        @metrics[:run_count] += 1
      end
    end

    def finalize
      @writers.each {|w| w.finalize if w.respond_to? :finalize}
    end
  end

  class UScheduler < Scheduler
    def process_queue
      while @loop.collectors.size < 5
        host, options = queue.shift
        break unless host
        @metrics[:nometrics] = 1 if host =~ /^GRIMETRICS/
        process1 'tra', host, options
      end
    end
  end
end
