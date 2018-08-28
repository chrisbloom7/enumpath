# frozen_string_literal: true

require 'logger'

module Enumpath
  class Logger
    PAD = "  "
    SEPARATOR = '--------------------------------------'

    attr_accessor :logger, :level

    def initialize(logdev = STDOUT)
      @logger = ::Logger.new(logdev)
      @level = 0
      @padding = {}
    end

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
