# frozen_string_literal: true

module Enumpath
  module Operator
    # Implements JSONPath child operator syntax. See {file:README.md#label-Child+operator} for syntax and examples.
    class Child < Base
      class << self
        # Checks to see if an operator is valid as a child operator. It is considered valid if the enumerable contains
        # an index, key, member, or property that responds to child.
        #
        # @param operator (see Enumpath::Operator::Base.detect?)
        # @return (see Enumpath::Operator::Base.detect?)
        def detect?(operator, enum)
          !Enumpath::Resolver::Simple.resolve(operator, enum).nil? ||
            !Enumpath::Resolver::Property.resolve(operator, enum).nil?
        end
      end

      # Resolves a child operator against an enumerable. If the child operator matches a index, key, member, or
      # property of the enumerable it is yielded to the block.
      #
      # @param (see Enumpath::Operator::Base#apply)
      # @yield (see Enumpath::Operator::Base#apply)
      # @yieldparam remaining_path [Array] remaining_path
      # @yieldparam enum [Enumerable] the resolved value of the enumerable
      # @yieldparam resolved_path [Array] resolved_path plus the child operator
      def apply(remaining_path, enum, resolved_path, &block)
        value = Enumpath::Resolver::Simple.resolve(operator, enum)
        value = Enumpath::Resolver::Property.resolve(operator, enum) if value.nil?
        yield(remaining_path, value, resolved_path + [operator]) if !value.nil?
      end
    end
  end
end
