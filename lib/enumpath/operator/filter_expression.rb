# frozen_string_literal: true

# Implements JSONPath filter expressions operator syntax `?(<boolean expr>)`
# The expression is evaluated as a property on each member of the local enumerable.
# If a comparison operator and an operand are included in the expression then the
# value of the property is compared against the operand, otherwise it is evaluated
# for thruthiness. If the result is true, then the member is yielded to the block,
# otherwise it is skipped. Expressions can be chained together with logical `&&`
# or `||` operators, in which case the results will be compared to each other in
# definition order.

require 'to_regexp'

module Enumpath
  module Operator
    class FilterExpression < Base
      COMPARISON_OPERATOR_REGEX = /(==|!=|>=|<=|<=>|>|<|=~|!~)/
      LOGICAL_OPERATORS_REGEX = /(&&)|(\|\|)/
      OPERATOR_REGEX = /^\?\((.*)\)$/

      class << self
        def detect?(operator)
          !!(operator =~ OPERATOR_REGEX)
        end
      end

      def apply(remaining_segments, enum, current_path, &block)
        Enumpath.log('Evaluating filter expression') { { expression: operator, to: enum } }

        _match, unpacked_operator = OPERATOR_REGEX.match(operator).to_a
        expressions = unpacked_operator.split(LOGICAL_OPERATORS_REGEX).map(&:strip)

        keys(enum).each do |key|
          value = Enumpath::Resolver::Simple.resolve(key, enum)
          Enumpath.log('Applying filter to key') { { key: key, enum: value } }
          if pass?(expressions.dup, value)
            Enumpath.log('Applying filtered key') { { 'filtered key': key, 'filtered enum': value } }
            yield(remaining_segments, value, current_path + [key.to_s])
          end
        end
      end

      private

      def pass?(expressions, enum)
        running_result = evaluate(expressions.shift, enum)
        Enumpath.log('Initial result') { { result: running_result } }
        while expressions.any? do
          logical_operator, expression = expressions.shift(2)
          running_result = evaluate(expression, enum, logical_operator, running_result)
          Enumpath.log('Running result') { { result: running_result } }
        end
        running_result
      end

      def evaluate(expression, enum, logical_operator = nil, running_result = nil)
        property, operator, operand = expression.split(COMPARISON_OPERATOR_REGEX).map(&:strip)
        value = resolve(property, enum)
        expression_result = test(operator, operand, value)
        Enumpath.log('Evaluated filter') do
          { property => value, operator: operator, operand: operand, result: expression_result,
            logical_operator: logical_operator }.compact
        end
        if logical_operator == '&&'
          Enumpath.log('&&=')
          running_result &&= expression_result
        elsif logical_operator == '||'
          Enumpath.log('||=')
          running_result ||= expression_result
        else
          expression_result
        end
      end

      def resolve(property, enum)
        return enum if property == '@'
        value = Enumpath::Resolver::Simple.resolve(property.gsub(/^@\./, ''), enum)
        value = Enumpath::Resolver::Property.resolve(property.gsub(/^@\./, ''), enum) if value.nil?
        value
      end

      def test(operator, operand, value)
        return !!value if operator.nil? || operand.nil?
        typecast_operand = variable_typecaster(operand)
        !!value.public_send(operator.to_sym, typecast_operand)
      rescue NoMethodError
        Enumpath.log('Filter could not be evaluated!')
        false
      end

      def variable_typecaster(variable)
        if variable =~ /\A('|").+\1\z/
          # It quacks like a string
          variable.gsub(/\A('|")|('|")\z/, '')
        elsif variable =~ /^:.+/
          # It quacks like a symbol
          variable.gsub(/\A:/, '').to_sym
        elsif variable =~ /true|false|nil/i
          # It quacks like an unquoted boolean operator
          variable == 'true' ? true : false
        elsif regexp = variable.to_regexp(literal: false, detect: false)
          # It quacks like a regex
          regexp
        else
          # Otherwise treat it as a number
          variable.to_f
        end
      end
    end
  end
end
