require File.expand_path(File.dirname(__FILE__) + '/unittest_helper')

require 'gri/main'

module GRI

class TestMain < Test::Unit::TestCase
  def test_main_optparse
    main = Main.new
    opts = {}

    optparser = main.instance_eval {optparse opts}
    argv = ['--config-path', '/tmp/gri.conf']
    optparser.parse argv
    ae '/tmp/gri.conf', opts[:config_path]
  end
end

end
