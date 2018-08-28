# frozen_string_literal: true

# Implements JSONPath wildcard operator syntax. Each member of the local enumerable
# is yielded to the block.

module Enumpath
  module Operator
    class Wildcard < Base
      OPERATOR = '*'

      class << self
        def detect?(operator)
          operator == OPERATOR
        end
      end

      def apply(remaining_segments, enum, current_path, &block)
        keys = keys(enum)
        Enumpath.log('Applying wildcard to keys') { { keys: keys } }
        keys.each { |key| yield([key.to_s] + remaining_segments, enum, current_path) }
      end
    end
  end
end
