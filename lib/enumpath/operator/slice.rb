# frozen_string_literal: true

# Implements JSONPath array slice operator syntax. Each member of the local enumerable
# whose index, key, or member is included by position between the _start index and up
# to (but not including) the _length_ is yielded to the block. If _step_ is included
# then only every _step_ member is included, starting with the first.

module Enumpath
  module Operator
    class Slice < Base
      OPERATOR_REGEX = /^(-?[0-9]*):(-?[0-9]*):?(-?[0-9]*)$/

      class << self
        def detect?(operator)
          !!(operator =~ OPERATOR_REGEX)
        end
      end

      def apply(remaining_segments, enum, current_path, &block)
        _match, start, length, step = OPERATOR_REGEX.match(operator).to_a
        max_length = enum.size
        slices(start, length, step, max_length).each do |index|
          Enumpath.log('Applying slice') { { slice: index } }
          yield([index.to_s] + remaining_segments, enum, current_path)
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
