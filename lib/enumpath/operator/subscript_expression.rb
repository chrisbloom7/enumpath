# frozen_string_literal: true

# Implements JSONPath subscript expressions operator syntax `(<expr>)`
# The expression is evaluated as a property on the local enumerable. If an arithmetic
# operator and operand are included in the expression then the value of the property
# is operated on with the operand and that is used as the new value. If the value
# maps to a member of the local enumerable then the member is yielded to the block.

module Enumpath
  module Operator
    class SubscriptExpression < Base
      ARITHMETIC_OPERATOR_REGEX = /(\+|-|\*\*|\*|\/|%)/
      OPERATOR_REGEX = /^\((.*)\)$/

      class << self
        def detect?(operator)
          !!(operator =~ OPERATOR_REGEX)
        end
      end

      def apply(remaining_path, enum, resolved_path, &block)
        Enumpath.log('Applying subscript expression') { { expression: operator, to: enum } }

        _match, unpacked_operator = OPERATOR_REGEX.match(operator).to_a
        result = evaluate(unpacked_operator, enum)

        value = Enumpath::Resolver::Simple.resolve(result, enum)
        if !value.nil?
          # yield([result.to_s] + remaining_path, enum, resolved_path)
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
