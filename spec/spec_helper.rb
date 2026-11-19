# frozen_string_literal: true

require 'bundler/setup'
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
    Enumpath.logger.logger = ::Logger.new('/dev/null')
  end

  # Enumpath.verbose is a process-wide default, so a spec that turns it on must not leave it on
  config.after { Enumpath.verbose = false }
end
