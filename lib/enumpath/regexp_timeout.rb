# frozen_string_literal: true

module Enumpath
  # Bounds how long a regular expression in a filter expression may run. A pattern with a backreference, such as
  # `/^(a*)*\1$/`, can take exponential time to match a short string, so a hostile or careless path could hang the
  # process.
  #
  # The limit uses the `timeout` of `Regexp.new`, which needs Ruby 3.2 or later. Older Rubies have no protection and
  # ignore the limit. Once one match runs out of time, every later regular expression match in the same
  # {Enumpath.apply} call is skipped and does not match, so the total delay is bounded by one limit, not one limit per
  # member of the data.
  module RegexpTimeout
    # The limit in seconds when {Enumpath.apply} is not given a `:regexp_timeout`
    DEFAULT = 1.0

    # Whether this Ruby can limit regular expressions
    SUPPORTED = Regexp.respond_to?(:timeout)

    # Raised when a match ran out of time, or when an earlier match in the same call did
    ERROR = SUPPORTED ? Regexp::TimeoutError : Class.new(StandardError)

    # The `Thread.current` key that holds the {State} for the current {Enumpath.apply} call
    THREAD_KEY = :enumpath_regexp_timeout

    # The limit for one {Enumpath.apply} call, and whether it has run out
    State = Struct.new(:seconds, :expired)

    class << self
      # Runs the block with a limit for regular expression matches, then restores the previous limit, even if the
      # block raises. Used by {Enumpath.apply}.
      #
      # @private
      # @param seconds [Numeric, nil] the limit in seconds; nil means no limit
      # @raise [ArgumentError] if the limit is not nil or a positive, finite number
      # @return the value of the block
      def with_limit(seconds)
        state = State.new(validate!(seconds), false)
        previous = Thread.current[THREAD_KEY]
        Thread.current[THREAD_KEY] = state
        begin
          yield
        ensure
          Thread.current[THREAD_KEY] = previous
        end
      end

      # Returns the regular expression with the current limit applied
      #
      # @param regexp [Regexp] the regular expression to limit
      # @raise [Enumpath::RegexpTimeout::ERROR] if an earlier match in this call ran out of time
      # @return [Regexp] a copy that raises {ERROR} when a match takes longer than the limit, or the regular
      #   expression itself when there is no limit or this Ruby cannot limit it
      def limit(regexp)
        state = Thread.current[THREAD_KEY]
        raise ERROR, 'an earlier regular expression ran out of time' if state&.expired

        seconds = state ? state.seconds : DEFAULT
        return regexp unless SUPPORTED && seconds

        Regexp.new(regexp.source, regexp.options, timeout: seconds)
      end

      # Records that a match ran out of time, so later matches in the same call are skipped
      #
      # @private
      def expire!
        state = Thread.current[THREAD_KEY]
        state.expired = true if state
      end

      private

      def validate!(seconds)
        return seconds if seconds.nil? || positive_finite?(seconds)

        raise ArgumentError, "regexp_timeout must be nil or a positive number of seconds, got #{seconds.inspect}"
      end

      def positive_finite?(number)
        number.is_a?(Numeric) && number.real? && number.positive? && number.finite?
      end
    end
  end
end
