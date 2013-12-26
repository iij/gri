# coding: us-ascii
require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'gri/msnmp'

class TestMSNMP < Test::Unit::TestCase
  def test_ber_enc
    # tag 0x02 == INT
    ae "\x02\x01\x00", BER.enc(0x02, 0)
    ae "\x02\x01\xFF", BER.enc(0x02, 255)
    ae "\x02\x02\x01\x00", BER.enc(0x02, 256)
    ae "\x02\x01\xff", BER.enc(0x02, -1)
    ae "\x02\x01\x80", BER.enc(0x02, -128)
    ae "\x02\x02\xff\x7f", BER.enc(0x02, -129)

    # tag 0x04 == STR
    ae "\x04\x01a", BER.enc(0x04, 'a')
    ae "\x04\x08abcdefgh", BER.enc(0x04, 'abcdefgh')
  end

  def test_ber_enc_len
    ae "\x1", BER.enc_len(1)
    ae "\x7f", BER.enc_len(127)
    ae "\x81\x80", BER.enc_len(128)
    ae "\x81\xff", BER.enc_len(255)
    ae "\x82\x01\x00", BER.enc_len(256)
    ae "\x82\xff\xff", BER.enc_len(65535)
  end

  def test_ber_enc_oid
    ae "+\x06\x01\x02\x01\x02", BER.enc_v_oid('1.3.6.1.2.1.2')
    ae "\x06\x06+\x06\x01\x02\x01\x02", BER.enc_oid('1.3.6.1.2.1.2')
  end

  def test_ber_enc_oid_list
    list = ['sysDescr', 'sysName'].map {|n| SNMP::OIDS[n] + '.0'}
    s = BER.enc_oid_list list
    t, val, remain = BER.tlv(s)
    ae 0x30, t
    assert remain.empty?
  end

  def test_ber_cat_enoid
    oids = [BER.enc_v_oid('1.3.6.1.2.1.1'), BER.enc_v_oid('1.3.6.1.2.1.2')]
    varbind = BER.cat_enoid oids
    t, val, remain = BER.tlv(varbind)
    ae 0x30, t
    assert remain.empty?
  end

  def test_dec_oid
    ae [1,3,6,1,2,1,2], BER.dec_oid(BER.enc_v_oid('1.3.6.1.2.1.2'))
  end

  def test_ber_dec_int
    ae 1, BER.dec_int("\x01")
    ae 127, BER.dec_int("\x7f")
    ae -128, BER.dec_int("\x80")
    ae -129, BER.dec_int("\xff\x7f")
  end

  def test_ber_dec_cnt
    ae 1, BER.dec_cnt("\x00\x00\x00\x01")
    ae(2**31+1, BER.dec_cnt("\x80\x00\x00\x01"))
  end

  def test_ber_tlv
    tag, val, remain = BER.tlv "\x04\x06public\x04\x08abcdefgh"
    ae 4, tag
    ae 'public', val
    ae "\x04\x08abcdefgh", remain

    s = 'a' * 200
    tag, val, remain = BER.tlv(BER.enc_str(s))
    ae 4, tag
    ae s, val
    assert remain.empty?

    s = 'a' * 300
    tag, val, remain = BER.tlv(BER.enc_str(s))
    ae 4, tag
    ae s, val
    assert remain.empty?
  end

  def test_ber_dec_msg
    varbind = "\0" * 160
    s = BER.enc_int(1234) + BER.enc_int(0) + BER.enc_int(0) + varbind
    s = "\xA2" + BER.enc_len(s.size) + s
    s = BER.enc_int(1) + BER.enc_str('public') + s
    msg = "\x30" + BER.enc_len(s.size) + s

    enc_request_id, error_status, error_index, varbind = BER.dec_msg msg
    ae BER.enc_int(1234), enc_request_id
    ae 0, error_status
    ae 0, error_index
  end

  def test_ber_dec_varbind_block
    oid = '1.3.6.1.2.1.6.9.0'
    s = BER.enc_oid(oid) + "B\x01\x10" # GAUGE 1 16
    msg = "\x30" + BER.enc_len(s.size) + s
    res, = BER.dec_varbind(msg)
    ae oid, BER.dec_oid(res[0]).join('.')
    ae 0x42, res[1] # GAUGE
    ae 16, res[2]

    oid = SNMP::OIDS['sysDescr']+'.0'
    s = BER.enc_oid(oid) + BER.enc_str("test")
    s = "\x30" + BER.enc_len(s.size) + s
    res, = BER.dec_varbind(s)
    ae oid, BER.dec_oid(res[0]).join('.')
    ae 0x04, res[1]
    ae 'test', res[2]
  end

  def test_snmp_enoid2name
    snmp = SNMP.new '127.0.0.1'
    enoid = BER.enc_v_oid SNMP::OIDS['system']
    ae 'system', snmp.enoid2name(enoid)
    enoid = BER.enc_v_oid '1.3.6.1.2.1.1.1.0'
    ae 'sysDescr.0', snmp.enoid2name(enoid)
  end

  def test_c64
    c = BER::C64.new "\0"
    ae "0x0000000000000000", c.to_s

    c = BER::C64.new "\x01\x00\x00"
    ae "0x0000000000010000", c.to_s
    ae 65536, c.to_i

    n = 0xffffffffffffffff
    c = BER::C64.new [n].pack('Q')
    ae "0xffffffffffffffff", c.to_s

    c = BER::C64.new "\x12\x34\x56\x78\xfe\xdc\xba\x98"
    ae "0x12345678fedcba98", c.to_s
    ae "\x124Vx\xFE\xDC\xBA\x98", c.to_binary
    ae "\xcf\x124Vx\xfe\xdc\xba\x98", c.to_msgpack

    c = BER::C64.new "\x01\x23\x45\x67\x89"
    ae "\xcf\x00\x00\x00\x01#Eg\x89", c.to_msgpack

    c = BER::C64.new "\x00\x03\x00\x00\x00\x00\x00\x00"
  end
end
