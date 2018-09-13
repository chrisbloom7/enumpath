# frozen_string_literal: true

module Enumpath
  module Operator
    # Implements JSONPath wildcard operator syntax. See {file:README.md#label-Wildcard+operator} for syntax and examples
    class Wildcard < Base
      OPERATOR = '*'

      class << self
        # Simple test of whether the operator matches the {Enumpath::Operator::Wildcard::OPERATOR} constant
        #
        # @param operator (see Enumpath::Operator::Base.detect?)
        # @return (see Enumpath::Operator::Base.detect?)
        def detect?(operator)
          operator == OPERATOR
        end
      end

      # Yields to the block once for every direct member of the enumerable
      #
      # @param (see Enumpath::Operator::Base#apply)
      # @yield (see Enumpath::Operator::Base#apply)
      # @yieldparam remaining_path [Array] the key of the given member plus remaining_path
      # @yieldparam enum [Enumerable] enum
      # @yieldparam resolved_path [Array] resolved_path
      def apply(remaining_path, enum, resolved_path)
        keys = keys(enum)
        Enumpath.log('Applying wildcard to keys') { { keys: keys } }
        keys.each { |key| yield([key.to_s] + remaining_path, enum, resolved_path) }
      end
    end
  end
end
