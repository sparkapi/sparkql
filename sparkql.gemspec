$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'sparkql/version'

Gem::Specification.new do |s|
  s.name        = 'sparkql'
  s.version     = Sparkql::V2::VERSION
  s.authors     = ['Wade McEwen']
  s.email       = ['wade@fbsdata.com']
  s.homepage    = ''
  s.summary     = 'API Parser engine for filter searching'
  s.description = 'Specification and base implementation of the Spark API parsing system.'

  s.rubyforge_project = 'sparkql'

  s.license       = 'Apache 2.0'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_dependency             'georuby', '~> 2.0'
  s.add_development_dependency 'ci_reporter', '~> 1.6'
  s.add_development_dependency 'mocha', '~> 0.12.0'
  s.add_development_dependency 'racc', '~> 1.4.8'
  s.add_development_dependency 'rake', '~> 0.9.2'
  s.add_development_dependency 'test-unit', '~> 2.1.0'
end
