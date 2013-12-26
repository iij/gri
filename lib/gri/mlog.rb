module Log
  extend Log

  def init(*args)
  end
  def write grp, str, severity=nil
  end
  def puts(*args)
  end
  def pp(*args)
  end
  def debug(*args, &block)
  end
  def info(*args, &block)
  end
  def warn(*args, &block)
  end
  def error(*args, &block)
  end
  def fatal(*args, &block)
  end
end
