require 'logger'

module Log
  IOBUF = {}

  class Formatter
    Format = "%s %s\n"
    attr_accessor :datetime_format

    def call severity, time, progname, msg
      tstr = time.strftime("%Y-%m-%d %H:%M:%S")
      Format % [tstr, msg2str(msg)]
    end

    def msg2str(msg)
      case msg
      when ::String
	msg
      when ::Exception
	"#{ msg.message } (#{ msg.class })\n" <<
	  (msg.backtrace || []).join("\n")
      else
	msg.inspect
      end
    end
  end

  class << self
    attr_accessor :logger
  end

  module_function

  def init logdev, options={}
    shift_age = options[:log_shift_age] || 8
    shift_size = options[:log_shift_size] || 100_000_000
    logger = Logger.new logdev, shift_age, shift_size
    logger.formatter = Log::Formatter.new
    logger.add Logger::INFO, '-' unless options[:no_dash]
    logger = Logger.new logdev
    logger.formatter = Log::Formatter.new
    logger.level = {'fatal'=>Logger::FATAL, 'error'=>Logger::ERROR,
      'warn'=>Logger::WARN, 'info'=>Logger::INFO, 'debug'=>Logger::DEBUG,
    }[(options[:log_level] || '').downcase] || Logger::INFO
    Log.logger = logger
  end

  def open logdev
    if logdev == '-'
      logdev = STDOUT
    end
    init logdev
  end

  def close grp=nil
    if @logger
      @logger.close
    else
      if grp
	if (io = IOBUF[grp])
	  io.close
	end
      else
	for io in IOBUF.values
	  io.close
	end
      end
    end
  end

  def write grp, str, severity=nil
    if @logger
      if severity.kind_of? Symbol
        severity = @logger.class.const_get severity
      else
        severity ||= @logger.class::INFO
      end
      begin
        logger.add severity, str.chomp
      rescue Logger::Error
        disable
      end
    else
      io = IOBUF[grp]
      if io
	if io.kind_of? File
	  #mtime = io.mtime
          tstr = Time.now.strftime("%Y-%m-%d %H:%M:%S ")
          gstr = (grp == :default) ? '' : "#{grp}: "
          io.print tstr + gstr + str
        else
          io.print str
          io.print "\n" if severity #XXX
        end
      end
    end
  end

  def puts(*args)
    if args.size >= 2 and args[0].kind_of?(Symbol)
      grp = args.shift
    else
      grp = :default
    end
    str = args.join('').chomp + "\n"
    self.write grp, str
  end

  def pp(*args)
    if args.size >= 2 and args[0].kind_of?(Symbol)
      self.puts args[0], args[1..-1].map {|e| e.inspect}.join(', ')
    else
      self.puts args.map {|e| e.inspect}.join(', ')
    end
  end

  def debug(*args, &block)
    write :default, args.first, :DEBUG
  end
  def info(*args, &block)
    write :default, args.first, :INFO
  end
  def warn(*args, &block)
    write :default, args.first, :WARN
  end
  def error(*args, &block)
    write :default, args.first, :ERROR
  end
  def fatal(*args, &block)
    write :default, args.first, :FATAL
  end

  def null(*args, &block)
  end

  def disable
    @logger = nil
    IOBUF.clear
  end
end
