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
    Enumpath navigates nested Ruby objects with JSONPath-style path expressions
    written as plain strings. It works on the data you actually have in memory:
    hashes with symbol, string or integer keys, arrays, Structs, plain objects
    and OpenStructs, in any mix. It is like Ruby's native dig, but a path can use
    wildcards, filters, slices, unions and recursive descent, so it can live in
    configuration or a database and change without a deploy. Paths are safe by
    default: a path can read your data but cannot call mutating methods such as
    clear or destroy. Only accept paths from sources you trust.
  DESC
  spec.authors       = ['Chris Bloom']
  spec.email         = ['chrisbloom7@gmail.com']

  # Ship only the library, the license and the README. Dir.glob is used instead of `git ls-files`
  # so the gem can be built outside a git checkout and never picks up repo tooling.
  spec.files         = Dir['lib/**/*'].select { |f| File.file?(f) }.sort + %w[LICENSE README.md]
  spec.require_paths = ['lib']

  spec.homepage      = 'https://github.com/chrisbloom7/enumpath'
  spec.metadata['rubygems_mfa_required'] = 'true'

  # CI tests Ruby 2.6 and newer
  spec.required_ruby_version = '>= 2.6.0'

  # No longer a default gem as of Ruby 4.0. The upper bound keeps RubyGems from warning about an open-ended dependency.
  spec.add_dependency 'logger', '>= 1.4', '< 3'
  spec.add_dependency 'mini_cache', '~> 1.1.0'
  spec.add_dependency 'to_regexp', '~> 0.2.1'

  spec.add_development_dependency 'null-logger', '~> 0.1'
  spec.add_development_dependency 'pry-byebug', '~> 3.9'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'redcarpet', '~> 3.5'
  spec.add_development_dependency 'rspec_junit_formatter', '~> 0.4'
  spec.add_development_dependency 'rspec-benchmark', '~> 0.6'
  spec.add_development_dependency 'rspec', '~> 3.10'
  spec.add_development_dependency 'yard', '~> 0.9'
end
