# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'stretcher/version'

Gem::Specification.new do |gem|
  gem.name          = "stretcher"
  gem.version       = Stretcher::VERSION
  gem.authors       = ["Andrew Cholakian"]
  gem.email         = ["andrew@andrewvc.com"]
  gem.description   = %q{The elegant ElasticSearch client}
  gem.summary       = %q{The elegant ElasticSearch client, supporting persistent connections, and a clean DSL}
  gem.homepage      = "https://github.com/PoseBiz/stretcher"
  gem.license = 'MIT'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  if RUBY_PLATFORM == 'java'
    gem.add_runtime_dependency('jruby-openssl')
  end

  gem.add_dependency('faraday', '~> 1.0.1')
  gem.add_dependency('faraday_middleware', '~> 1.0.0')
  gem.add_dependency('excon', '>= 0.76.0')
  gem.add_dependency('hashie', '>= 4.1.0')
  gem.add_dependency('multi_json', '>= 1.15.0')

  gem.add_development_dependency 'rspec', '>= 3.9'
  gem.add_development_dependency 'coveralls', '>= 0.8.23'
  gem.add_development_dependency 'simplecov'
  gem.add_development_dependency 'vcr'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'its'
  gem.add_development_dependency 'pry'

end
