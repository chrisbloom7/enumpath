# frozen_string_literal: true

# Implements JSONPath union operator syntax. The operator consistes of
# a set of names or indices. Any member of the local enumerable that can
# be found at any of the keys or indices is yielded to the block.

# TODO: Investigate supporting anchored paths (`$.foo.bar...`, `@.foo.bar...`)

module Enumpath
  module Operator
    class Union < Base
      OPERATOR = /,/
      CONSTRAINTS = /^,|,$/
      SPLIT_REGEX = /,/

      class << self
        def detect?(operator)
          operator.scan(',').any? && operator.scan(CONSTRAINTS).none?
        end
      end

      def apply(remaining_segments, enum, current_path, &block)
        parts = operator.split(SPLIT_REGEX).map { |part| part.strip.gsub(/^['"]|['"]$/, '') }
        Enumpath.log('Applying union parts') { { parts: parts } }
        parts.each { |part| yield([part] + remaining_segments, enum, current_path) }
      end
    end
  end
end
