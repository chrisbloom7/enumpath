
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "enumpath/version"

Gem::Specification.new do |spec|
  spec.name          = "enumpath"
  spec.version       = Enumpath::VERSION
  spec.authors       = ["Chris Bloom"]
  spec.email         = ["chrisbloom7@gmail.com"]

  spec.summary       = "A JSONPath-compatible library for navigating Ruby objects using path expressions"
  spec.homepage      = "https://github.com/youearnedit/enumpath"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.require_paths = ["lib"]

  # Enumerable#dig was added in Ruby 2.3.0
  spec.required_ruby_version = '>= 2.3.0'

  spec.add_dependency "to_regexp", "~> 0.2.1"
  spec.add_dependency "mini_cache", "~> 1.1.0"

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "null-logger", "~> 0.1"
  spec.add_development_dependency "pry-byebug", "~> 3.6"
  spec.add_development_dependency "rake", "~> 12.3"
  spec.add_development_dependency "rspec-benchmark", "~> 0.3.0"
  spec.add_development_dependency "rspec", "~> 3.8"
end
