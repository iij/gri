module GRI
  class FakeSock
    def recv *arg; end
  end

  class FakeSNMP
    attr_reader :state
    attr_accessor :version

    def initialize path
      lines = File.readlines path
      @lines = []
      lines.each {|line|
        oid, value = line.split ' = '
        value = vconv value
        enoid = BER.enc_v_oid oid[1..-1]
        @lines.push [enoid, value] if value
      }

      @sock = FakeSock.new

      @roids = SNMP::ROIDS
      @state = :IDLE
    end

    def get_value enoid
      (res = @lines.assoc enoid) ? res[1] : nil
    end

    def sock; @sock; end

    def recv_msg msg
      for arg in @get_buf
        @cb.call *arg
      end
      @get_buf.clear
      @state = :SUCCESS
      nil
    end

    def get_start msg, &cb
      @cb = cb
      @state = :GET_REQ
      @get_buf = []
      tag, msg, = BER.tlv msg
      while msg.size > 0
        tag, val, msg = BER.tlv msg
        if val.getbyte(0) == 6
          len = val.getbyte(1)
          enoid = val[2, len]
          if (value = get_value(enoid))
            @get_buf.push [enoid, value[0], value[1]]
          end
        end
      end
    end

    def walk_start enoid, &cb
      @cb = cb
      @state = :GETBULK_REQ

      @get_buf = []
      for k, v in @lines
        if k.index(enoid) == 0
          @get_buf.push [k, v[0], v[1]]
        end
      end
    end

    def make_req state, arg
      nil
    end

    def vconv str
      case str
      when /^INTEGER: (\d+)/
        [0x02, $1.to_i]
      when /^STRING: "(.*)/
        [0x04, $1[0..-2]]
      when /^STRING: ([^"].*)/
        [0x04, $1]
      when /^OID: \.(1.*)/
        enoid = BER.enc_v_oid $1
        [0x06, enoid]
      when /^Counter(?:32)?: (\d+)/
        [0x41, $1.to_i]
      when /^Gauge(?:\d+): (\d+)/
        [0x42, $1.to_i]
      when /^Counter64: (\d+)/
        [0x46, $1.to_i]
      else
        nil
      end
    end
  end
end
