require 'rubygems'
begin
  require 'simplecov'
  SimpleCov.start
rescue LoadError
end
require 'test/unit'
require 'pp'

$test_dir = File.expand_path File.dirname(__FILE__)
$:.unshift $test_dir
$:.unshift($test_dir + '/../lib')
require 'gri/q'
$test = true
#$debug = true

module Test
  module Unit
    module Assertions
      alias ae assert_equal
    end
  end
end

unless ARGV.grep(/--show-log/).empty?
  $show_log = true
end
