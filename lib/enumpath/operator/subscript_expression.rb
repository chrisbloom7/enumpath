# frozen_string_literal: true

module Enumpath
  module Operator
    # Implements JSONPath subscript expressions operator syntax. See
    # {file:README.md#label-Subscript+expressions+operator} for syntax and examples
    class SubscriptExpression < Base
      ARITHMETIC_OPERATOR_REGEX = /(\+|-|\*\*|\*|\/|%)/
      OPERATOR_REGEX = /^\((.*)\)$/

      class << self
        # Whether the operator matches {Enumpath::Operator::SubscriptExpression::OPERATOR_REGEX}
        #
        # @param operator (see Enumpath::Operator::Base.detect?)
        # @return (see Enumpath::Operator::Base.detect?)
        def detect?(operator)
          !!(operator =~ OPERATOR_REGEX)
        end
      end

      # Yields to the block once if the subscript expression evaluates to a member of the enumerable
      #
      # @param (see Enumpath::Operator::Base#apply)
      # @yield (see Enumpath::Operator::Base#apply)
      # @yieldparam remaining_path [Array] remaining_path
      # @yieldparam enum [Enumerable] the member of the enumerable at the value of the subscript expression
      # @yieldparam resolved_path [Array] resolved_path plus the value of the subscript expression
      def apply(remaining_path, enum, resolved_path, &block)
        Enumpath.log('Applying subscript expression') { { expression: operator, to: enum } }

        _match, unpacked_operator = OPERATOR_REGEX.match(operator).to_a
        result = evaluate(unpacked_operator, enum)

        value = Enumpath::Resolver::Simple.resolve(result, enum)
        if !value.nil?
          Enumpath.log('Applying subscript') { { 'enum at subscript': value } }
          yield(remaining_path, value, resolved_path + [result.to_s])
        end
      end

      private

      def evaluate(unpacked_operator, enum)
        property, operator, operand = unpacked_operator.split(ARITHMETIC_OPERATOR_REGEX).map(&:strip)
        test(operator, operand, resolve(property, enum))
      end

      def resolve(property, enum)
        return enum if property == '@'
        value = Enumpath::Resolver::Simple.resolve(property.gsub(/^@\./, ''), enum)
        value = Enumpath::Resolver::Property.resolve(property.gsub(/^@\./, ''), enum) if value.nil?
        value
      end

      def test(operator, operand, value)
        if operator.nil? || operand.nil?
          Enumpath.log('Simple subscript') { { subscript: value } }
          value
        else
          # Evaluate expression using operator
          typecast_operand = variable_typecaster(operand)
          result = value.public_send(operator.to_sym, typecast_operand)
          Enumpath.log('Evaluated subscript') do
            { value: value, operator: operator, operand: typecast_operand, result: result }
          end
          result
        end
      rescue NoMethodError
        Enumpath.log('Subscript could not be evaluated') { { subscript: nil } }
        nil
      end

      def variable_typecaster(variable)
        if variable =~ /\A('|").+\1\z/ || variable =~ /^:.+/
          # It quacks like a string or symbol
          variable.gsub(/\A(:|('|"))|('|")\z/, '')
        else
          # Otherwise treat it as a number. Note that we only care about whole numbers in this case
          variable.to_i
        end
      end
    end
  end
end
