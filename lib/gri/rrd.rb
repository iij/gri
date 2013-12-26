require 'open3'

class RRDError < Exception; end

module RRDm
  extend RRDm

  @@rrdtool_path = (Dir.glob('/usr/local/rrdtool-*/bin/rrdtool').sort.reverse +
		  ['/usr/local/bin/rrdtool', '/usr/bin/rrdtool']).find {|path|
    File.executable? path.untaint
  }

  attr_reader :version

  def start rrdtool_path=nil
    rrdtool_path ||= @@rrdtool_path
    raise RuntimeError, 'rrdtool is already running' if @sequence
    unless rrdtool_path and File.exist?(rrdtool_path)
      raise Exception, "rrdtool #{rrdtool_path} not found"
    end
    @sequence = 'S'
    @last_cmd = nil

    @in, @out, @err = Open3.popen3("#{rrdtool_path} -")
    @in.sync = true
    @out.sync = true

    cmd 'version'
    line, = read
    @version, = line.scan(/^RRDtool\s+(\S+)/)[0]
  end

  def running?
    @sequence
  end

  def read out=nil
    unless @sequence == 'C'
      raise RuntimeError, 'RRDm.read can only be called after RRDm.cmd'
    end
    @sequence == 'R'
    lines = []
    errline = nil

    while line = @out.gets
      if line =~ /^ERROR/
	errline = line.gsub(/\n/, "\\n")
        raise RuntimeError, errline
      elsif line =~ /^OK u:([\d\.]+) s:([\d\.]+) r:([\d\.]+)/
	sys, user, real = $1.to_f, $2.to_f, $3.to_f
	if errline
	  raise RuntimeError, errline
	else
	  return [lines.join(''), sys, user, real]
	end
      end
      if out
        out.write line
      else
        lines.push line
      end
    end
    raise RuntimeError, 'unexpected EOF'
  end

  def cmd(*args)
    @sequence = 'C'
    cmd = args.join(' ')
    @in.print cmd, "\n"
    @last_cmd = cmd
  end

  def close
    @sequence = nil
    @in.close
    @out.close
    @err.close
  end
end

class RRD
  attr_accessor :width, :height
  attr_accessor :title, :vertical_label
  attr_accessor :imgformat
  attr_accessor :lower_limit
  attr_accessor :x_grid_hash
  attr_accessor :fonts
  attr_reader :created_p
  attr_reader :ds_ary
  attr_reader :version
  attr_writer :show_graph_date

  def initialize address=nil, base_dir=nil
    @address = address
    @base_dir = base_dir

    @imgformat = 'PNG'
    @update_buf = []
    @x_grid_hash = {}
    @show_graph_date = false
    @fonts = []
    RRDm.start unless RRDm.running?
    @version = (RRDm.version =~ /\A(1\.\d)\./) ? $1 : '1.0'
  end

  def set_create_args *args
    @rrdname = args.shift
    if @rrdname
      @created_p = File.exist? @rrdname
      @args = args
    end
  end

  def remove_base_dir *args
    return args unless @base_dir
    if @base_dir[-1, 1] == ?/
      base_dir = @base_dir
    else
      base_dir = @base_dir + '/'
    end
    re = /\A#{base_dir}/
    args.map {|arg| arg.sub(re, '')}
  end

  def create start=nil, step=nil, *args
    str = ''
    if start
      start = start.to_i
      str = "--start #{start} "
    end
    if step
      str += "--step #{step}"
    end
    RRDm.cmd 'create', @rrdname, str, *args
    return RRDm.read
  end
  private :create

  def buffered_update(*args)
    res = flush_buffer if @update_buf.size > 40
    @update_buf += args
    res
  end

  def flush_buffer v=false
    if @update_buf.size > 0
      begin
	unless @created_p
	  create *@args
	  @created_p = true
	end
        res = update *@update_buf
      end
      @update_buf = []
    end
    res
  end

  def update(*args)
    daemon = @address ? " --daemon #{@address}" : ''
    path = remove_base_dir @rrdname
    RRDm.cmd "update#{daemon}", path.first, *args
    begin
      str, = RRDm.read
    rescue RuntimeError => e
      if e.message =~ /last update time is (\d+)/
        last_update = $1.to_i
        pargs = []
        args.each {|arg|
          if arg.split(':')[0].to_i > last_update
            pargs.push arg
          end
        }
        if pargs.size == 0
          return nil
        end
        args = pargs
        RRDm.cmd "update#{daemon}", path, *args
        str, = RRDm.read rescue nil
      else
        Log.error "#{@rrdname}: #{$!}"
      end
    end
    lines = str.split(/\n/).select {|line| line =~ /^\[/} if str
    lines
  end

  def graph fname, starttime, endtime, *misc_args
    starttime = starttime.to_i
    endtime = endtime.to_i
    if misc_args.first.kind_of? Symbol
      cmd = misc_args.shift.to_s
    else
      daemon = @address ? " --daemon #{@address}" : ''
      cmd = "graph#{daemon}"
    end
    args = [cmd, fname, '--start', starttime, '--end', endtime]
    args.push '--slope-mode' if @version >= '1.2'
    args.push '--width ' + @width.to_s if @width
    args.push '--height ' + @height.to_s if @height
    args.push '--lower-limit ' + @lower_limit.to_s if @lower_limit
    args.push '--imgformat ' + @imgformat
    args.push '--title ' + @title if @title
    args.push '--vertical-label ' + @vertical_label if @vertical_label
    if @version >= '1.3'
      for fstr in @fonts
        (fstr =~ /^(DEFAULT|TITLE|AXIS|UNIT|LEGEND):(\d+):/) and
          args.push "-n \"#{fstr}\""
      end
    end

    dt = endtime - starttime
    vtime = Time.at(starttime)
    vcolor = '#ff7f7f'
    xgrid = nil
    if dt < 3 * 3600
      vtime = Time.local(vtime.year, vtime.mon, vtime.day) + 24*3600
      args.push "VRULE:#{vtime.to_i}#{vcolor}" if vtime.to_i < endtime
      xgrid = 'MINUTE:10:HOUR:1:MINUTE:10:0:%H:%M'
    elsif dt < 12 * 3600
      vtime = Time.local(vtime.year, vtime.mon, vtime.day) + 24*3600
      args.push "VRULE:#{vtime.to_i}#{vcolor}" if vtime.to_i < endtime
      xgrid = 'MINUTE:30:HOUR:1:HOUR:1:0:%H:%M'
    elsif dt < 6 * 24 * 3600
      vtime = Time.local(vtime.year, vtime.mon, vtime.day) + 24*3600
      while vtime.to_i < endtime
	args.push "VRULE:#{vtime.to_i}#{vcolor}"
	vtime += 24*3600
      end
      xgrid = 'HOUR:1:HOUR:6:HOUR:6:0:%H:%M'
    elsif dt < 14 * 24 * 3600
      tmptime = vtime + ((8 - vtime.wday) % 7)*24*3600
      vtime = Time.local(tmptime.year, tmptime.mon, tmptime.day)
      while vtime.to_i < endtime
	args.push "VRULE:#{vtime.to_i}#{vcolor}"
	vtime += 7*24*3600
      end
      xgrid = 'HOUR:6:DAY:1:DAY:1:86400:%a'
    elsif dt < 90 * 24 * 3600
      tmptime = Time.local(vtime.year, vtime.mon) + 31*24*3600 + 3610
      vtime = Time.local(tmptime.year, tmptime.mon)
      while vtime.to_i < endtime
	args.push "VRULE:#{vtime.to_i}#{vcolor}"
	tmptime = vtime + 31*24*3600 + 3610
	vtime = Time.local(tmptime.year, tmptime.mon, 1)
      end
      xgrid = 'DAY:1:WEEK:1:WEEK:1:86400:%m/%d'
    else
      vtime = Time.local(vtime.year+1)
      while vtime.to_i < endtime
	args.push "VRULE:#{vtime.to_i}#{vcolor}"
	vtime = Time.local(vtime.year+1)
      end
      xgrid = 'MONTH:3:YEAR:1:YEAR:1:31536000:%Y' if dt > 400 * 24 * 3600
    end
    args.push "--x-grid \"#{xgrid}\"" if xgrid

    if @show_graph_date
      cstr = "COMMENT:" +
	Time.at(starttime).strftime('"%Y/%m/%d %H:%M - ') +
	Time.at(endtime).strftime('%Y/%m/%d %H:%M\n"')
      args.push cstr
    end

    args += misc_args
    RRDm.cmd args
    return RRDm.read
  end

  def fetch cf, resolution=nil, starttime=nil, endtime=nil
    args = []
    if resolution
      resolution = resolution.to_i
      if starttime and endtime
	starttime = starttime.to_i / resolution * resolution
	endtime = endtime.to_i / resolution * resolution
      end
      args.push ['--resolution', resolution]
    end
    args.push ['--start', starttime.to_i] if starttime
    args.push ['--end', endtime.to_i] if endtime
    RRDm.cmd 'fetch', @rrdname, cf, *args
    str, = RRDm.read
    collect = []
    s = nil #XXX
    for line in str.split("\n")
      timestr, *remain = line.split
      time = timestr.to_i
      if time > 0
	collect.push [Time.at(time),
	  remain.collect {|s|
	    if s =~ /^nan$/i
	      nil
	    else
	      s.to_f
	    end
	  }]
      else
	ds_ary = line.split
	ds_ary.shift
	@ds_ary = ds_ary if ds_ary.size > 0
      end
    end
    return collect
  end

  def tune args
    RRDm.cmd 'tune', @rrdname, *args
    str, = RRDm.read
    return str.split("\n")
  end

  def resize num, deltasize
    if deltasize >= 0
      rrcmd = 'GROW'
    else
      rrcmd = 'SHRINK'
    end
    RRDm.cmd 'resize', @rrdname, num, rrcmd, deltasize.abs
    str, = RRDm.read
    File.rename 'resize.rrd', @rrdname
    return str.split("\n")
  end

  def info
    RRDm.cmd 'info', @rrdname
    str, = RRDm.read
    return str.split("\n")
  end

  def dump dst=nil
    tmp_path = dst || "/tmp/rrdtmp#{$$}.xml"
    open(tmp_path, 'w') {|out|
      RRDm.cmd 'dump', @rrdname#, tmp_path
      str, = RRDm.read out
    }
    return tmp_path
  end

  def restore src=nil
    tmp_path = src
    RRDm.cmd 'restore', tmp_path, @rrdname
    str, = RRDm.read
    return tmp_path
  end

  def xport starttime, endtime, *misc_args
    starttime = starttime.to_i
    endtime = endtime.to_i
    cmd = "xport#{@address ? " --daemon #{@address}" : ''}"
    args = [cmd, '--json', '--start', starttime, '--end', endtime] + misc_args
    RRDm.cmd args
    str, = RRDm.read
    return str
  end

  def rrainfo
    ary = info
    rra = []
    step, = ary[2].scan(/^step = (\d+)$/)[0]
    if step
      for line in ary
	if line =~ /^rra\[(\d+)\]\.(.*)/
	  num = $1.to_i
	  remain = $2
	  #p [$1, remain]
	  rra[num] = [] unless rra[num]
	  case remain
	  when /^cf = "(\w+)"/
	    rra[num][0] = $1
	  when /^rows = (\d+)/
	    rra[num][1] = $1.to_i
	  when /^pdp_per_row = (\d+)/
	    rra[num][2] = $1.to_i
	  end
	end
      end
    end
    return step, rra
  end

  def graphgen stime, etime, args
    tmp_file = "/tmp/rrdtmp#{$$}"
    img = nil
    graph tmp_file, stime, etime, args
    open(tmp_file) {|f| img = f.read}
    File.unlink tmp_file
    img
  end

  def self.defstr rrdpaths, ds, cf, cname, line, color, legend,
      mag=1, lower_bound=nil, upper_bound=nil
    expr = []
    st = {}
    n = 0

    limitstr = if lower_bound and upper_bound and (lower_bound != upper_bound)
		 ",#{lower_bound},#{upper_bound},LIMIT"
               elsif lower_bound
                 ",DUP,#{lower_bound},GE,EXC,UNKN,IF"
	       else
		 ''
	       end
    if rrdpaths.size > 1
      vnames = []
      for rrdpath in rrdpaths
	basename = File.basename rrdpath, '.rrd'
	vname = "v#{st[basename] ||= (n+=1)}#{ds}"
	vnames.push vname
        expr.push "DEF:#{vname}=#{rrdpath}:#{ds}:#{cf} "
      end
      tmpstr = "CDEF:#{cname}=" +
	vnames.map {|vname|
        "#{vname},UN,0,#{vname},IF,#{mag},*#{limitstr}"
        }.join(',') + ',+' * (vnames.size-1)
      expr.push tmpstr
      #expr.push ',FLOOR' if ds =~ /(in|out)ucast/
    else
      rrdpath, = rrdpaths
      expr.push "DEF:v#{cname}=#{rrdpath}:#{ds}:#{cf} "
      expr.push "CDEF:#{cname}=v#{cname}#{limitstr},#{mag},* "
    end

    if line == 'XPORT'
      expr.push " XPORT:#{cname}:\"#{legend}\""
    else
      expr.push " #{line}:#{cname}#{color}"
      unless legend == '-'
        esc_legend = legend.gsub(':', '\:')
        expr.push ":\"#{esc_legend}\" "
        expr.push "GPRINT:#{cname}:MAX:\"(max\\:%.2lf%s\" "
        expr.push "GPRINT:#{cname}:AVERAGE:\"avg\\:%.2lf%s\" "
        expr.push "GPRINT:#{cname}:LAST:\"last\\:%.2lf%s)\""
      end
    end
    return expr.join('')
  end
end
