class MockLoop
  def initialize
    @handlers = {}
    @rs = []
  end

  def attach collector
    collector.attach self
  end

  def detach collector
    collector.on_detach
  end

  def on_detach &on_detach
    @on_detach = on_detach
  end

  def watch io, flag, to, handler
    @handlers[io] = handler
    @rs.push io
  end

  def run
  end

  def run_handler ind
    io = @rs[ind]
    @handlers[io].on_readable io
  end
end

class MockIO
  def close; end
end

module MockFork
  def fork &cb
    1
  end
end

class MockUDPSocket
  attr_accessor :data

  def connect host, port
    @host = host
    @port = port
  end

  def send msg, flags
    @msg = msg
  end

  def recv maxlen, flags
    @data
  end

  def close; end
end
