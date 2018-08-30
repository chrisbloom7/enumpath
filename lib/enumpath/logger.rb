# frozen_string_literal: true

require 'logger'

module Enumpath
  # A logger for providing debugging information while evaluating path expressions
  # @private
  class Logger
    PAD = "  "

    SEPARATOR = '--------------------------------------'

    # @return [Integer] the indentation level to apply to log messages
    attr_accessor :level

    # @return [::Logger, #<<] a {::Logger}-compatible logger instance
    attr_accessor :logger

    # @param logdev [String, IO] The log device. See Ruby's {::Logger.new} documentation.
    def initialize(logdev = STDOUT)
      @logger = ::Logger.new(logdev)
      @level = 0
      @padding = {}
    end

    # Generates a log message for debugging. Returns fast if {Enumpath.verbose} is false. Accepts an optional block
    # which must contain a single hash, the contents of which will be added to the log message, and which are lazily
    # evaluated only if {Enumpath.verbose} is true.
    #
    # @param title [String] the title of this log message
    # @yield A lazily evaluated hash of key/value pairs to include in the log message
    def log(title)
      return unless Enumpath.verbose
      append_log "#{padding}#{SEPARATOR}\n"
      append_log "#{padding}Enumpath: #{title}\n"
      if block_given?
        append_log "#{padding}#{SEPARATOR}\n"
        vars = yield
        return unless vars.is_a?(Hash)
        label_size = vars.keys.map(&:size).max
        vars.each do |label, value|
          append_log "#{padding}#{label.to_s.ljust(label_size)}: #{massaged_value(value)}\n"
        end
      end
    end

    private

    def append_log(message)
      logger << message
    end

    def massaged_value(value)
      if value.is_a?(Enumerable)
        enum_for_log(value)
      elsif value.is_a?(TrueClass)
        'True'
      elsif value.is_a?(FalseClass)
        'False'
      elsif value.nil?
        'Nil'
      else
        value.to_s
      end
    end

    def enum_for_log(enum, length = 50)
      json = enum.inspect
      "#{json[0...length]}#{json.length > length ? '...' : ''}"
    end

    def padding
      PAD * level.to_i
    end
  end
end
