# frozen_string_literal: true

require 'bundler/setup'
require 'rspec-benchmark'
require 'enumpath'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) do
    # Swallow output from the Enumpath logger
    Enumpath.logger.logger = ::Logger.new('/dev/null')
  end

  # Do not run performance tests by default
  config.filter_run_excluding perf: true
end
