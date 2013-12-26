# coding: us-ascii

require 'fileutils'

if File.symlink? __FILE__
  pdir = File.dirname(File.expand_path(File.readlink(__FILE__)))
else
  pdir = File.dirname(File.expand_path(__FILE__))
end
$LOAD_PATH.push pdir unless $LOAD_PATH.index pdir
pdir = pdir + '/../..'
$LOAD_PATH.push pdir unless $LOAD_PATH.index pdir

require 'gri/log'
require 'gri/builtindefs'
require 'gri/msnmp'
require 'gri/vendor'
require 'gri/plugin'
require 'gri/updater'
require 'gri/rrd'
require 'gri/ltsv'

module Fluent

class GriOutput < BufferedOutput
  Plugin.register_output('gri', self)

  config_param :gra_dir, :string, :default=>'/usr/local/gri/gra'

  def configure conf
    super
  end

  def start
    super
    #::Log.init '/tmp/fluent.log'
    GRI::Plugin.load_plugins []
    GRI::Config.init
  end

  def format tag, time, record
    [tag, time, record].to_msgpack
  end

  def write chunk
    records = []
    chunk.msgpack_each {|tag, time, record|
      records.push record
    }
    writer = GRI::Writer.create 'rrd', :gra_dir=>@gra_dir
    writer.write records
    writer.finalize
  end
end

end
