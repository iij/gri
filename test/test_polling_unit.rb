# coding: us-ascii
require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'gri/msnmp'
require 'gri/builtindefs'
require 'gri/polling_unit'

module GRI
  class TestPollingUnit < Test::Unit::TestCase
    def test_polling_unit_all_units
      units = PollingUnit.all_units
      assert_kind_of PollingUnit, units['interfaces']
      assert_kind_of PollingUnit, units['ifMIB']
      assert_kind_of PollingUnit, units['ipaddr']
    end

    def test_polling_unit
      pu = PollingUnit.new 'test', :test
      ae 'test', pu.name
      pu.dhash = {}
      oids = ['ifDescr', 'ifSpeed', 'ifAdminStatus', 'ifOperStatus']
      pu.set_oids oids
      ae 4, pu.oids.size
      ae "+\x06\x01\x02\x01\x02\x02\x01\x02", pu.oids.first
    end

    def test_polling_unit_feed
      snmp = SNMP.new 'host'

      workhash = {''=>{}}

      units = PollingUnit.all_units
      pu = units['interfaces']
      wh = workhash[pu.cat]
      enoid = BER.enc_v_oid(SNMP::OIDS['ifDescr'] + '.1')
      pu.feed wh, enoid, 4, 'lo'
      ae 'lo', wh[1]['ifDescr']
      enoid = BER.enc_v_oid(SNMP::OIDS['ifDescr'] + '.2')
      pu.feed wh, enoid, 4, 'eth0'
      ae 'eth0', wh[2]['ifDescr']

      pu = units['ifMIB']
      wh = workhash[pu.cat]
      enoid = BER.enc_v_oid(SNMP::OIDS['ifHighSpeed'] + '.2')
      pu.feed wh, enoid, 2, 10000
      ae 10000, wh[2]['ifHighSpeed']
      pu.fix_workhash workhash
      ae 10000000000, wh[2]['ifSpeed']

      workhash[:ipaddr] = {
        '192.168.0.1'=>{'ifIndex'=>2, 'mask'=>'255.255.255.0'}
      }
      pu = units['ipaddr']
      pu.fix_workhash workhash
      ae '192.168.0.1/255.255.255.0', wh[2]['ipaddr']
    end
  end
end
