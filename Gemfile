# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in enumpath.gemspec
gemspec

# ostruct became a bundled gem (no longer a default gem) in Ruby 3.5/4.0; the object traversal spec needs it
gem 'ostruct' if RUBY_VERSION >= '3.5'
