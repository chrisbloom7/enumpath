# frozen_string_literal: true

require 'logger'

module Enumpath
  # A logger for providing debugging information while evaluating path expressions
  # @private
  class Logger
    PAD = '  '

    SEPARATOR = '--------------------------------------'

    # The `Thread.current` key that holds the indentation level of the current thread
    LEVEL_KEY = :enumpath_log_level

    # @return [::Logger, #<<] a {::Logger}-compatible logger instance
    attr_accessor :logger

    # @param logdev [String, IO] The log device. See Ruby's {::Logger.new} documentation.
    def initialize(logdev = STDOUT)
      @logger = ::Logger.new(logdev)
      @padding = {}
    end

    # The indentation level to apply to log messages. It belongs to the current thread, so the calls that threads
    # make at the same time do not change each other's indentation.
    #
    # @return [Integer]
    def level
      Thread.current[LEVEL_KEY] || 0
    end

    # @param value [Integer] the indentation level for the current thread
    def level=(value)
      Thread.current[LEVEL_KEY] = value
    end

    # Generates a log message for debugging. Returns fast if {Enumpath.verbose} is false. Accepts an optional block
    # which must contain a single hash, the contents of which will be added to the log message, and which are lazily
    # evaluated only if {Enumpath.verbose} is true.
    #
    # @param title [String] the title of this log message
    # @yield A lazily evaluated hash of key/value pairs to include in the log message
    def log(title)
      return unless Enumpath.verbose

      pad = padding
      message = +"#{pad}#{SEPARATOR}\n#{pad}Enumpath: #{title}\n"
      if block_given?
        message << "#{pad}#{SEPARATOR}\n"
        message << vars_message(yield, pad)
      end
      # One write per message, so messages from threads that log at the same time do not interleave their lines
      append_log(message)
    end

    private

    def append_log(message)
      logger << message
    end

    def vars_message(vars, pad)
      return '' unless vars.is_a?(Hash)

      label_size = vars.keys.map(&:size).max
      vars.map { |label, value| "#{pad}#{label.to_s.ljust(label_size)}: #{massaged_value(value)}\n" }.join
    end

    def massaged_value(value) # rubocop:disable Metrics/MethodLength
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
