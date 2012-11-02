# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "sparkql/version"

Gem::Specification.new do |s|
  s.name        = "sparkql"
  s.version     = Sparkql::VERSION
  s.authors     = ["Wade McEwen"]
  s.email       = ["wade@fbsdata.com"]
  s.homepage    = ""
  s.summary     = %q{API Parser engine for filter searching}
  s.description = %q{Specification and base implementation of the Spark API parsing system.}

  s.rubyforge_project = "sparkql"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency 'racc', '1.4.8'
  s.add_development_dependency 'flexmls_gems', '~> 0.2.9'
  s.add_development_dependency 'rake', '~> 0.9.2'
  s.add_development_dependency 'test-unit', '~> 2.1.0'
  s.add_development_dependency 'ci_reporter', '~> 1.6'
  s.add_development_dependency 'mocha', '~> 0.12.0'
  s.add_development_dependency 'rcov', '~> 0.9.9'

end
