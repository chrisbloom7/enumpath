# frozen_string_literal: true

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
          !(operator =~ OPERATOR_REGEX).nil?
        end
      end

      # Yields to the block once for each member of the enumerable that passes the filter expression
      #
      # @param (see Enumpath::Operator::Base#apply)
      # @yield (see Enumpath::Operator::Base#apply)
      # @yieldparam remaining_path [Array] remaining_path
      # @yieldparam enum [Enumerable] the member of the enumerable that passed the filter
      # @yieldparam resolved_path [Array] resolved_path plus the key for each member of the enumerable that passed
      #   the filter
      def apply(remaining_path, enum, resolved_path, &block)
        Enumpath.log('Evaluating filter expression') { { expression: operator, to: enum } }
        _match, unpacked_operator = OPERATOR_REGEX.match(operator).to_a
        expressions = unpacked_operator.split(LOGICAL_OPERATORS_REGEX).map(&:strip)
        keys(enum).each { |key| apply_to_key(key, expressions, remaining_path, enum, resolved_path, &block) }
      end

      private

      def apply_to_key(key, expressions, remaining_path, enum, resolved_path)
        value = Enumpath::Resolver::Simple.resolve(key, enum)
        Enumpath.log('Applying filter to key') { { key: key, enum: value } }
        return unless pass?(expressions.dup, value, expressions.size > 1 ? {} : nil)

        Enumpath.log('Applying filtered key') { { 'filtered key': key, 'filtered enum': value } }
        yield(remaining_path, value, resolved_path + [key.to_s])
      end

      # `resolved` (nil when there is a single expression) holds each property already resolved for this member, so a
      # property repeated across the logical expressions is resolved (and any method it calls is run) once
      def pass?(expressions, enum, resolved)
        running_result = evaluate(expressions.shift, enum, resolved)
        Enumpath.log('Initial result') { { result: running_result } }
        while expressions.any?
          logical_operator, expression = expressions.shift(2)
          running_result = evaluate(expression, enum, resolved, logical_operator, running_result)
          Enumpath.log('Running result') { { result: running_result } }
        end
        running_result
      end

      def evaluate(expression, enum, resolved, logical_operator = nil, running_result = nil)
        property, operator, operand = expression.split(COMPARISON_OPERATOR_REGEX).map(&:strip)
        value = resolved ? resolve_once(resolved, property, enum) : resolve(property, enum)
        expression_result = test(operator, operand, value)
        Enumpath.log('Evaluated filter') do
          { property => value, operator: operator, operand: operand, result: expression_result,
            logical_operator: logical_operator }.compact
        end
        running_result(logical_operator, running_result, expression_result)
      end

      def resolve_once(resolved, property, enum)
        resolved.fetch(property) { resolved[property] = resolve(property, enum) }
      end

      def resolve(property, enum)
        return enum if property == '@'

        value = Enumpath::Resolver::Simple.resolve(property.gsub(/^@\./, ''), enum)
        value = Enumpath::Resolver::Property.resolve(property.gsub(/^@\./, ''), enum) if value.nil?
        value
      end

      def test(operator, operand, value)
        return (value ? true : false) if operator.nil? || operand.nil?

        matching_nothing_on_error do
          value.public_send(operator.to_sym, variable_typecaster(operand)) ? true : false
        end
      end

      # A comparison that cannot be evaluated, or a regular expression that is not valid or ran out of time, does not
      # match
      def matching_nothing_on_error
        yield
      rescue Enumpath::RegexpTimeout::ERROR
        Enumpath::RegexpTimeout.expire!
        no_match('Regular expression ran out of time!')
      rescue RegexpError
        no_match('Regular expression is not valid!')
      rescue NoMethodError
        no_match('Filter could not be evaluated!')
      end

      def no_match(reason)
        Enumpath.log(reason)
        false
      end

      def variable_typecaster(variable) # rubocop:disable Metrics/MethodLength
        if variable =~ /\A('|").+\1\z/
          # It quacks like a string
          variable.gsub(/\A('|")|('|")\z/, '')
        elsif variable =~ /^:.+/
          # It quacks like a symbol
          variable.gsub(/\A:/, '').to_sym
        elsif variable =~ /true|false|nil/i
          # It quacks like an unquoted boolean operator
          variable == 'true'
        elsif (regexp = Enumpath::RegexpParser.parse(variable))
          # It quacks like a regex
          Enumpath::RegexpTimeout.limit(regexp)
        else
          # Otherwise treat it as a number
          variable.to_f
        end
      end

      def running_result(logical_operator, running_result, expression_result)
        if logical_operator == '&&'
          Enumpath.log('&&=')
          running_result && expression_result
        elsif logical_operator == '||'
          Enumpath.log('||=')
          running_result || expression_result
        else
          expression_result
        end
      end
    end
  end
end
