$:.push File.expand_path("../lib", __FILE__)
require "gri/version"

Gem::Specification.new do |s|
  s.name = "gri"
  s.version = GRI::VERSION
  s.authors = ["maebashi"]
  s.homepage = ""
  s.summary = %q{GRI}
  s.description = %q{GRI}
  s.files         = `git ls-files`.split("\n").select {|e| /^tmp/!~e}
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f
) }
  s.require_paths = ["lib"]

  s.add_development_dependency "msgpack"
  s.add_runtime_dependency "rack", '< 3'
end
