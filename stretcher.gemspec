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

  if RUBY_VERSION < "1.9"
    gem.add_runtime_dependency('json')
  end

  gem.add_dependency('faraday', '~> 0.8')
  gem.add_dependency('faraday_middleware', '~> 0.9')
  gem.add_dependency('excon', '>= 0.16')
  gem.add_dependency('hashie', '>= 1.2.0')

  gem.add_development_dependency 'rspec', '>= 2.5.0'
  gem.add_development_dependency 'coveralls'
  gem.add_development_dependency 'simplecov'
  gem.add_development_dependency 'vcr'
  gem.add_development_dependency 'rake'
end
