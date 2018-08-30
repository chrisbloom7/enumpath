# frozen_string_literal: true

# TODO: Investigate supporting anchored paths (`$.foo.bar...`, `@.foo.bar...`)

module Enumpath
  module Operator
    # Implements JSONPath union operator syntax. See {file:README.md#label-Union+operator} for syntax and examples
    class Union < Base
      OPERATOR = /,/
      CONSTRAINTS = /^,|,$/
      SPLIT_REGEX = /,/

      # The operator consists of
      # a set of names or indices. Any member of the local enumerable that can
      # be found at any of the keys or indices is yielded to the block.

      class << self
        # Whether the operator matches {Enumpath::Operator::Union::OPERATOR} and does not match
        # {Enumpath::Operator::Union::CONSTRAINTS}
        #
        # @param operator (see Enumpath::Operator::Base.detect?)
        # @return (see Enumpath::Operator::Base.detect?)
        def detect?(operator)
          operator.scan(',').any? && operator.scan(CONSTRAINTS).none?
        end
      end

      # Yields to the block once for every union member
      #
      # @param (see Enumpath::Operator::Base#apply)
      # @yield (see Enumpath::Operator::Base#apply)
      # @yieldparam remaining_path [Array] the union member plus remaining_path
      # @yieldparam enum [Enumerable] enum
      # @yieldparam resolved_path [Array] resolved_path
      def apply(remaining_path, enum, resolved_path, &block)
        parts = operator.split(SPLIT_REGEX).map { |part| part.strip.gsub(/^['"]|['"]$/, '') }
        Enumpath.log('Applying union parts') { { parts: parts } }
        parts.each { |part| yield([part] + remaining_path, enum, resolved_path) }
      end
    end
  end
end
