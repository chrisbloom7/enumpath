# frozen_string_literal: true

module Enumpath
  module Operator
    # Implements JSONPath array slice operator syntax. See {file:README.md#label-Slice+operator} for syntax and examples
    class Slice < Base
      OPERATOR_REGEX = /^(-?[0-9]*):(-?[0-9]*):?(-?[0-9]*)$/

      class << self
        # Whether the operator matches {Enumpath::Operator::Slice::OPERATOR_REGEX}
        #
        # @param operator (see Enumpath::Operator::Base.detect?)
        # @return (see Enumpath::Operator::Base.detect?)
        def detect?(operator)
          !(operator =~ OPERATOR_REGEX).nil?
        end
      end

      # Yields to the block once for each member of the local enumerable whose index is included by position between
      # _start_ and up to (but not including) _end_. If _step_ is included then only every _step_ member is included,
      # starting with the first.
      #
      # @param (see Enumpath::Operator::Base#apply)
      # @yield (see Enumpath::Operator::Base#apply)
      # @yieldparam remaining_path [Array] the included index plus remaining_path
      # @yieldparam enum [Enumerable] enum
      # @yieldparam resolved_path [Array] resolved_path
      def apply(remaining_path, enum, resolved_path)
        _match, start, length, step = OPERATOR_REGEX.match(operator).to_a
        max_length = enum.size
        slices(start, length, step, max_length).each do |index|
          Enumpath.log('Applying slice') { { slice: index } }
          yield([index.to_s] + remaining_path, enum, resolved_path)
        end
      end

      private

      def slices(start, length, step, max_length)
        start = slice_start(start, max_length)
        length = slice_length(length, max_length)
        step = slice_step(step)
        (start...length).step(step)
      end

      def slice_start(start, max_length)
        start = start.empty? ? 0 : start.to_i
        start.negative? ? [0, start + max_length].max : [max_length, start].min
      end

      def slice_length(length, max_length)
        length = length.empty? ? max_length : length.to_i
        length.negative? ? [0, length + max_length].max : [max_length, length].min
      end

      def slice_step(step)
        step.empty? ? 1 : step.to_i
      end
    end
  end
end
