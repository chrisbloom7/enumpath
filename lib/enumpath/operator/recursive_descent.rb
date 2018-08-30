# frozen_string_literal: true

module Enumpath
  module Operator
    # Implements JSONPath recursive descent operator syntax. See {file:README.md#label-Recursive+descent+operator} for
    # syntax and examples
    class RecursiveDescent < Base
      OPERATOR = '..'

      class << self
        # Simple test of whether the operator matches the {Enumpath::Operator::RecursiveDescent::OPERATOR} constant
        #
        # @param operator (see Enumpath::Operator::Base.detect?)
        # @return (see Enumpath::Operator::Base.detect?)
        def detect?(operator)
          !!(operator == OPERATOR)
        end
      end

      # Yields to the block once for the enumerable itself, and once for every direct member of the enumerable that is
      # also an enumerable
      #
      # @param (see Enumpath::Operator::Base#apply)
      # @yield (see Enumpath::Operator::Base#apply)
      # @yieldparam remaining_path [Array] remaining_path for the enumerable itself, or the recursive descent
      #   operator plus remaining_path for each direct enumerable member
      # @yieldparam enum [Enumerable] enum for the enumerable itself, or the direct enumerable member for each direct
      #   enumerable member
      # @yieldparam resolved_path [Array] resolved_path for the enumerable itself, or resolved_path plus the key for
      #   each direct enumerable member
      def apply(remaining_path, enum, resolved_path, &block)
        Enumpath.log('Applying remaining path recursively to enum') { { 'remaining path': remaining_path } }
        yield(remaining_path, enum, resolved_path)
        keys(enum).each do |key|
          value = Enumpath::Resolver::Simple.resolve(key, enum)
          if recursable?(value)
            Enumpath.log('Applying remaining path recursively to key') do
              { key: key, 'remaining path': ['..'] + remaining_path }
            end
            yield(['..'] + remaining_path, value, resolved_path + [key])
          end
        end
      end

      private

      def recursable?(value)
        value.is_a?(Enumerable)
      end
    end
  end
end
