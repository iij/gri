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

  config_param :config_path, :string, :default=>'/usr/local/gri/gri.conf'
  config_param :gra_dir, :string, :default=>nil
  config_param :log_level, :string, :default=>nil
  config_param :interval, :integer, :default=>nil

  def start
    super
    if @log_level
      ::Log.init '/tmp/out_gri.log', :log_level=>@log_level
    end
    GRI::Config.init @config_path
    root_dir = GRI::Config['root-dir'] ||= GRI::Config::ROOT_PATH
    plugin_dirs = GRI::Config.getvar('plugin-dir') || [root_dir + '/plugin']
    GRI::Plugin.load_plugins plugin_dirs
    @gra_dir ||= GRI::Config['gra-dir'] || root_dir + '/gra'
    @interval ||= (GRI::Config['interval'] || 300).to_i
  end

  def format tag, time, record
    [tag, time, record].to_msgpack
  end

  def write chunk
    records = []
    chunk.msgpack_each {|tag, time, record|
      records.push record
    }
    writer = GRI::Writer.create 'rrd', :gra_dir=>@gra_dir, :interval=>@interval
    writer.write records
    writer.finalize
  end
end

class TraOutput < BufferedOutput
  Plugin.register_output('tra', self)

  config_param :config_path, :string, :default=>'/usr/local/gri/gri.conf'
  config_param :tra_dir, :string, :default=>nil
  config_param :log_level, :string, :default=>nil
  config_param :interval, :integer, :default=>nil

  def start
    super
    if @log_level
      ::Log.init '/tmp/out_tra.log', :log_level=>@log_level
    end
    GRI::Config.init @config_path
    root_dir = GRI::Config['root-dir'] ||= GRI::Config::ROOT_PATH
    plugin_dirs = GRI::Config.getvar('plugin-dir') || [root_dir + '/plugin']
    GRI::Plugin.load_plugins plugin_dirs
    @tra_dir ||= GRI::Config['tra-dir'] || root_dir + '/tra'
    @interval ||= (GRI::Config['interval'] || 300).to_i
  end

  def format tag, time, record
    [tag, time, record].to_msgpack
  end

  def write chunk
    records = []
    chunk.msgpack_each {|tag, time, record|
      records.push record
    }
    writer = GRI::Writer.create 'ldb', :tra_dir=>@tra_dir, :interval=>@interval
    writer.write records
    writer.finalize
  end
end

end
