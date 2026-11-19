# frozen_string_literal: true

module Enumpath
  # Parses the regular expression literals that a filter expression accepts (`/pattern/flags` and `%r{pattern}flags`)
  # into a Regexp. The pattern is passed to `Regexp.new` as text and never evaluated as Ruby code, so `#{...}` in it
  # stays plain text.
  module RegexpParser
    LITERAL = %r{\A(?:/(.*)/|%r\{(.*)\})([a-z]*)\z}m.freeze
    FLAGS = { 'i' => Regexp::IGNORECASE, 'm' => Regexp::MULTILINE, 'x' => Regexp::EXTENDED, 'n' => Regexp::NOENCODING,
              'u' => 0 }.freeze

    class << self
      # @param string [String] an operand from a path
      # @raise [RegexpError] if the string is a regular expression literal whose pattern is not valid
      # @return [Regexp, nil] the regular expression, or nil if the string is not a regular expression literal (this
      #   includes flags other than `i`, `m`, `x`, `n` and `u`)
      def parse(string)
        match = LITERAL.match(string)
        return unless match

        options = options_for(match[3])
        return if options.nil?

        # An escaped delimiter and a plain delimiter mean the same inside a pattern
        pattern = (match[1] || match[2]).gsub('\\/', '/')
        Regexp.new(pattern, options)
      end

      private

      def options_for(flags)
        return if flags.each_char.any? { |flag| !FLAGS.key?(flag) }

        flags.each_char.reduce(0) { |options, flag| options | FLAGS.fetch(flag) }
      end
    end
  end
end
