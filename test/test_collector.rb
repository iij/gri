# coding: us-ascii

require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'socket'
require 'mock'
require 'gri/log'
require 'gri/collector'

module GRI

class MockSNMP < SNMP
  def connect
    @sock = MockUDPSocket.new
    @sock.connect @host, @port
  end
end

class TestCollector < Test::Unit::TestCase
  TEST_SYS = "0\x81\xF2\x02\x01\x01\x04\bpublic00\xA2\x81\xE2\x02" +
    "\x02\x03\xE9\x02\x01\x00\x02\x01\x000\x81\xD50d\x06\b+\x06\x01" +
    "\x02\x01\x01\x01\x00\x04XLinux xxxxx.yyyyy.zzz.com " +
    "X.X.XX-XXX.XX.X.XXX #1 SMP Thu Oct 31 12:00:00 EDT 2013 x86_64" +
    "0\x1F\x06\b+\x06\x01\x02\x01\x01\x05\x00\x04\x13xxxxx.yyyyy.zzz.com" +
    "0\x16\x06\b+\x06\x01\x02\x01\x01\x02\x00\x06\n+\x06\x01\x04\x01" +
    "\xBF\b\x03\x02\n0\x10\x06\b+\x06\x01\x02\x01\x01\x03\x00C\x04" +
    "\x7F\xC9i\xA10\"\x06\b+\x06\x01\x02\x01\x01\x06\x00" +
    "\x04\x16xxxxx xxxx, xxxxx xxx."

  def test_snmp_collecotr
    c = Collector.create('snmp', 'testhost', {}) {|records|}
    snmp = MockSNMP.new 'testhost'
    c.instance_eval {
      @loop = MockLoop.new
      @snmp = snmp
    }

    rs = {}
    c.get(SNMPCollector::SYSOIDS) {|results|
      results.each {|enoid, tag, val| rs[SNMP::ROIDS[enoid]] = val}
    }
    ae :GET_REQ, snmp.state

    ae 0, c.instance_eval('@retry_count')
    c.retry
    ae 1, c.instance_eval('@retry_count')

    snmp.sock.data = TEST_SYS
    c.on_readable
    ae rs['sysName.0'], 'xxxxx.yyyyy.zzz.com'

    enoid = BER.enc_v_oid SNMP::OIDS['ipAdEntIfIndex']
    c.walk(enoid) {|enoid, tag, val|}
    ae :GETNEXT_REQ, snmp.state
  end
end

end
