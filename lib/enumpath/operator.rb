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
      def detect(operator, enum)
        if Enumpath::Operator::Child.detect?(operator, enum)
          Enumpath.log('Child operator detected')
          Enumpath::Operator::Child.new(operator)
        elsif Enumpath::Operator::Wildcard.detect?(operator)
          Enumpath.log('Wildcard operator detected')
          Enumpath::Operator::Wildcard.new(operator)
        elsif Enumpath::Operator::RecursiveDescent.detect?(operator)
          Enumpath.log('Recursive Descent operator detected')
          Enumpath::Operator::RecursiveDescent.new(operator)
        elsif Enumpath::Operator::Union.detect?(operator)
          Enumpath.log('Union operator detected')
          Enumpath::Operator::Union.new(operator)
        elsif Enumpath::Operator::SubscriptExpression.detect?(operator)
          Enumpath.log('Subscript Expression operator detected')
          Enumpath::Operator::SubscriptExpression.new(operator)
        elsif Enumpath::Operator::FilterExpression.detect?(operator)
          Enumpath.log('Filter Expression operator detected')
          Enumpath::Operator::FilterExpression.new(operator)
        elsif Enumpath::Operator::Slice.detect?(operator)
          Enumpath.log('Slice operator detected')
          Enumpath::Operator::Slice.new(operator)
        else
          Enumpath.log('Not a valid operator for enum')
          nil
        end
      end
    end
  end
end
