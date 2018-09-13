# frozen_string_literal: true

require 'enumpath/operator/base'
require 'enumpath/operator/child'
require 'enumpath/operator/filter_expression'
require 'enumpath/operator/recursive_descent'
require 'enumpath/operator/subscript_expression'
require 'enumpath/operator/slice'
require 'enumpath/operator/union'
require 'enumpath/operator/wildcard'

module Enumpath
  # Namespace for classes that represent path expression operators
  module Operator
    ROOT = '$'

    class << self
      # Infer the type of operator and return an instance of its Enumpath::Operator subclass
      #
      # @param operator [String] the operator to infer type on
      # @param enum [Enumerable] the enumerable to assist in detecting child operators
      # @return an instance of a subclass of Enumpath::Operator based on what was detected, or nil if nothing was
      #   detected
      def detect(operator, enum) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        return operator(:Child, operator) if child?(operator, enum)
        return operator(:Wildcard, operator) if wildcard?(operator)
        return operator(:RecursiveDescent, operator) if recursive_descent?(operator)
        return operator(:Union, operator) if union?(operator)
        return operator(:SubscriptExpression, operator) if subscript_expression?(operator)
        return operator(:FilterExpression, operator) if filter_expression?(operator)
        return operator(:Slice, operator) if slice?(operator)

        Enumpath.log('Not a valid operator for enum')
        nil
      end

      private

      def child?(operator, enum)
        Enumpath::Operator::Child.detect?(operator, enum)
      end

      def wildcard?(operator)
        Enumpath::Operator::Wildcard.detect?(operator)
      end

      def recursive_descent?(operator)
        Enumpath::Operator::RecursiveDescent.detect?(operator)
      end

      def union?(operator)
        Enumpath::Operator::Union.detect?(operator)
      end

      def subscript_expression?(operator)
        Enumpath::Operator::SubscriptExpression.detect?(operator)
      end

      def filter_expression?(operator)
        Enumpath::Operator::FilterExpression.detect?(operator)
      end

      def slice?(operator)
        Enumpath::Operator::Slice.detect?(operator)
      end

      def operator(operator_class, operator)
        Enumpath.log("#{operator_class} operator detected")
        klass = Object.const_get("Enumpath::Operator::#{operator_class}")
        klass.new(operator)
      end
    end
  end
end
