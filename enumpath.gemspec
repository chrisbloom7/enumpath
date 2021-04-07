# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'enumpath/version'

Gem::Specification.new do |spec|
  spec.name          = 'enumpath'
  spec.version       = Enumpath::VERSION
  spec.license       = 'Apache-2.0'
  spec.summary       = 'A JSONPath-compatible library for navigating nested Ruby objects using path expressions'
  spec.description = <<~DESC
    Enumpath is an implementation of the JSONPath spec for Ruby objects,
    plus some added sugar. It's like Ruby's native Enumerable#dig method,
    but fancier. It is designed for situations where you need to provide
    a dynamic way of describing a complex path through nested enumerable
    objects. This makes it exceptionally well suited for flexible ETL
    (Extract, Transform, Load) processes by allowing you to define paths
    through your data in a simple, easily readable, easily storable syntax.
  DESC
  spec.authors       = ['Chris Bloom']
  spec.email         = ['chrisbloom7@gmail.com']

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.require_paths = ['lib']

  spec.homepage      = 'https://github.com/chrisbloom7/enumpath'

  # Enumerable#dig was added in Ruby 2.3.0
  spec.required_ruby_version = '>= 2.3.0'

  spec.add_dependency 'mini_cache', '~> 1.1.0'
  spec.add_dependency 'to_regexp', '~> 0.2.1'

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'null-logger', '~> 0.1'
  spec.add_development_dependency 'pry-byebug', '~> 3.6'
  spec.add_development_dependency 'rake', '~> 12.3'
  spec.add_development_dependency 'rspec', '~> 3.8'
  spec.add_development_dependency 'rspec-benchmark', '~> 0.3.0'
  spec.add_development_dependency 'rspec_junit_formatter', '~> 0.4'
  spec.add_development_dependency 'yard', '~> 0.9.26'
end
