# frozen_string_literal: true

require 'to_regexp'

module Enumpath
  module Operator
    # Implements JSONPath filter expression operator syntax. See {file:README.md#label-Filter+expression+operator} for
    # syntax and examples
    class FilterExpression < Base
      COMPARISON_OPERATOR_REGEX = /(==|!=|>=|<=|<=>|>|<|=~|!~)/
      LOGICAL_OPERATORS_REGEX = /(&&)|(\|\|)/
      OPERATOR_REGEX = /^\?\((.*)\)$/

      class << self
        # Whether the operator matches {Enumpath::Operator::FilterExpression::OPERATOR_REGEX}
        #
        # @param operator (see Enumpath::Operator::Base.detect?)
        # @return (see Enumpath::Operator::Base.detect?)
        def detect?(operator)
          !!(operator =~ OPERATOR_REGEX)
        end
      end

      # Yields to the block once for each member of the enumerable that passes the filter expression
      #
      # @param (see Enumpath::Operator::Base#apply)
      #
      # @yieldparam remaining_path [Array] {remaining_path} as-is
      # @yieldparam enum [Enumerable] the member of the enumerable that passed the filter
      # @yieldparam resolved_path [Array] {resolved_path} plus the key for each member of the enumerable that passed
      #   the filter
      def apply(remaining_path, enum, resolved_path, &block)
        Enumpath.log('Evaluating filter expression') { { expression: operator, to: enum } }

        _match, unpacked_operator = OPERATOR_REGEX.match(operator).to_a
        expressions = unpacked_operator.split(LOGICAL_OPERATORS_REGEX).map(&:strip)

        keys(enum).each do |key|
          value = Enumpath::Resolver::Simple.resolve(key, enum)
          Enumpath.log('Applying filter to key') { { key: key, enum: value } }
          if pass?(expressions.dup, value)
            Enumpath.log('Applying filtered key') { { 'filtered key': key, 'filtered enum': value } }
            yield(remaining_path, value, resolved_path + [key.to_s])
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
