require 'timeout'
require 'gri/util_marshal'
require 'gri/app_collector'

module GRI
  class AppCollector
    def run_para targets, scheduler_class, start_time, fdh
      sock_path = config['sock-path'] || '/tmp/.gcollectsock'
      begin
        server_sock = UNIXServer.new sock_path
      rescue SystemCallError
        puts "#{$!}: server_sock error" if $debug
        Log.fatal "#{$!}: server_sock error"
        return
      end

      duration = (config['duration'] || 0).to_i
      if duration.zero?
        basetime = start_time
        offset = 0
      else
        basetime = start_time - start_time % duration
        offset = start_time - basetime
      end
      interval = (config['interval'] || 300).to_i
      ptargets = get_ptargets targets, basetime, duration, offset, interval
      log_dir = config['log-dir'] || (config['root-dir'] + '/log')
      Dir.glob("#{log_dir}/res.*.dump") {|path| File.unlink path} rescue nil
      max_processes = (config['max-processes'] ||
                       config['max-fork-process']).to_i
      max_processes = 30 if max_processes < 1
      nproc = [targets.size * 2 / 3 + 1, max_processes].min
      waittime = [20, duration].min
      begin
        pids = fork_child server_sock, sock_path, nproc, targets, log_dir,
          scheduler_class, fdh
        server_loop targets, ptargets, server_sock, waittime
      rescue TimeoutError, SystemCallError
        Log.error $!.inspect
      ensure
        server_sock.close
        Log.info "server_sock.close"
        File.unlink sock_path
      end
      pids.each {|pid| Process.waitpid pid}
      Dir.glob("#{log_dir}/res.#{$$}.*.dump") {|path|
        begin
          res = Marshal.load_from_file path
          res.each {|k, v| @metrics[k] += v}
          File.unlink path
        rescue SystemCallError
          Log.error "{$!}"
        end
      }
    end

    def server_loop targets, ptargets, server_sock, waittime
      sock = nil
      pkeys = ptargets.keys.sort
      pts = []
      while true
        break if pkeys.empty?
        now = Time.now.to_f
        t = pkeys.first
        if t <= now
          pkeys.shift
          pts += ptargets[t]
          while (n = pts.shift)
            timeout(waittime) {sock = server_sock.accept}
            if (res = IO.select(nil, [sock], nil, 20))
              thost = targets[n].first
              sock.puts "#{n} #{thost}"
              sock.close
            else
              sock.close
              raise TimeoutError, 'select timeout'
            end
            if pts.empty? and (t = pkeys.first)
              now = Time.now.to_f
              if t <= now
                pkeys.shift
                small, big = [pts, ptargets[t]].sort_by {|e| e.size}
                pts.replace big.zip(small)
                pts.flatten!
                pts.compact!
                #pts += ptargets[t]
              end
            end
          end
        else
          sleep(t - now)
        end
      end
    end

    def get_ptargets targets, basetime, duration, offset=0, default_interval=300
      if duration.zero?
        ptargets = {basetime=>(0..targets.size-1).to_a}
      else
        intervals = {}
        n = 0
        for host, options in targets
          interval = (options['interval'] || default_interval).to_i
          next if interval.zero?
          (intervals[interval] ||= []).push n
          n += 1
        end
        ptargets = {}
        et = basetime + duration
        for interval in intervals.keys
          st = basetime - basetime % interval
          (0..duration/interval).each {|n|
            s = n * interval
            if (t = st + s) >= basetime and t < et
              ptargets[t+offset] ||= []
              ptargets[t+offset] += intervals[interval]
            end
          }
        end
      end
      ptargets
    end

    def get_max_queue_size
      4
    end

    def fillup_queue n, sock_path, targets, scheduler
      e = false
      mqs = get_max_queue_size
      while scheduler.queue.size < mqs
        begin
          unless File.socket? sock_path
            e = true
            break
          end
          sock = UNIXSocket.new sock_path
        rescue Errno::ECONNREFUSED
          sock.close rescue nil
          sleep(0.1 + rand)
          retry
        rescue SystemCallError
          sock.close rescue nil
          e = true
          break
        end
        begin
          unless (line = sock.gets)
            e = true
            break
          end
        rescue
          e = true
          break
        ensure
          sock.close
        end
        num, host = line.split
        scheduler.queue.push targets[num.to_i]
        scheduler.process_queue
      end
      e
    end

    def fork_child server_sock, sock_path, nproc, targets, log_dir,
        scheduler_class, fdh
      pids = []
      ppid = $$
      for n in 1..nproc
        pid = fork {
          server_sock.close
          start_time = Time.now
          sleep 0.05 * n
          Log.debug "child ##{n}"
          loop = Loop.new
          @writers.each {|writer| writer.loop = loop}
          scheduler = scheduler_class.new loop, @metrics
          scheduler.queue = []
          scheduler.writers = @writers
          scheduler.fake_descr_hash = fdh

          e = fillup_queue n, sock_path, targets, scheduler
          scheduler.process_queue
          if !e or loop.has_active_watchers?
            while true
              loop.run_once
              break if e and !loop.has_active_watchers?
              e = fillup_queue n, sock_path, targets, scheduler
              scheduler.process_queue
            end
          end
          scheduler.finalize
          rc = @metrics[:run_count]
          elapsed = Time.now - start_time
          Log.debug "end ##{n} #{rc} #{rc/elapsed}"
          #@metrics["run_count#{n}".intern] = rc
          begin
            path = "#{log_dir}/res.#{ppid}.#{$$}.dump"
            Marshal.dump_to_file @metrics, path
          rescue SystemCallError
            Log.error "#{$!}"
          end
        }
        pids.push pid
      end
      pids
    end
  end
end
