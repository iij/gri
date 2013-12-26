module Process
  class << self
    unless method_defined?(:daemon)
      def daemon(nochdir = nil, noclose = nil)
        exit!(0) if Process.fork
        Process.setsid
        exit!(0) if Process.fork
        Dir.chdir("/") unless nochdir
        unless noclose
          #File.umask(0)
          STDIN.reopen("/dev/null", "r")
          STDOUT.reopen("/dev/null", "w")
          STDERR.reopen("/dev/null", "w")
        end
        0
      end
    end
  end
end
