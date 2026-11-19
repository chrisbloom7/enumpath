# frozen_string_literal: true

module Enumpath
  module Operator
    # Implements JSONPath subscript expressions operator syntax. See
    # {file:README.md#label-Subscript+expressions+operator} for syntax and examples
    class SubscriptExpression < Base
      ARITHMETIC_OPERATOR_REGEX = %r{(\+|-|\*\*|\*|\/|%)}
      OPERATOR_REGEX = /^\((.*)\)$/

      # The operand of an arithmetic expression comes from the path, so an expression that could use an unbounded
      # amount of CPU or memory is not evaluated and matches nothing. A subscript is an index or a key, so none of
      # these limits get in the way of a useful expression.
      #
      # The widest integer operand allowed, in bits
      MAX_OPERAND_BITS = 64
      # The most elements or characters that repeating a string or array (`*`) may produce
      MAX_REPEAT_SIZE = 10_000
      # The widest result allowed for an integer raised to a power (`**`), in bits
      MAX_POWER_BITS = 1_024

      # Errors from evaluating an expression against data that does not fit it, such as a string plus a number or a
      # division by zero. The expression matches nothing in these cases.
      EVALUATION_ERRORS = [NoMethodError, TypeError, ArgumentError, ZeroDivisionError, RangeError].freeze

      class << self
        # Whether the operator matches {Enumpath::Operator::SubscriptExpression::OPERATOR_REGEX}
        #
        # @param operator (see Enumpath::Operator::Base.detect?)
        # @return (see Enumpath::Operator::Base.detect?)
        def detect?(operator)
          !(operator =~ OPERATOR_REGEX).nil?
        end
      end

      # Yields to the block once if the subscript expression evaluates to a member of the enumerable
      #
      # @param (see Enumpath::Operator::Base#apply)
      # @yield (see Enumpath::Operator::Base#apply)
      # @yieldparam remaining_path [Array] remaining_path
      # @yieldparam enum [Enumerable] the member of the enumerable at the value of the subscript expression
      # @yieldparam resolved_path [Array] resolved_path plus the value of the subscript expression
      def apply(remaining_path, enum, resolved_path)
        Enumpath.log('Applying subscript expression') { { expression: operator, to: enum } }

        _match, unpacked_operator = OPERATOR_REGEX.match(operator).to_a
        result = evaluate(unpacked_operator, enum)

        value = Enumpath::Resolver::Simple.resolve(result, enum)
        Enumpath.log('Applying subscript') { { 'enum at subscript': value } } unless value.nil?
        yield(remaining_path, value, resolved_path + [result.to_s]) unless value.nil?
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
          evaluate_with_operator(operator, operand, value)
        end
      rescue *EVALUATION_ERRORS
        Enumpath.log('Subscript could not be evaluated') { { subscript: nil } }
        nil
      end

      def evaluate_with_operator(operator, operand, value)
        typecast_operand = variable_typecaster(operand)
        unless within_limits?(operator, typecast_operand, value)
          Enumpath.log('Subscript exceeds the arithmetic limits') { { operator: operator, operand: typecast_operand } }
          return nil
        end

        result = value.public_send(operator.to_sym, typecast_operand)
        Enumpath.log('Evaluated subscript') do
          { value: value, operator: operator, operand: typecast_operand, result: result }
        end
        result
      end

      # Whether evaluating `value <operator> operand` stays inside the limits above, before any work is done
      def within_limits?(operator, operand, value)
        return false if operand.is_a?(Integer) && operand.abs.bit_length > MAX_OPERAND_BITS

        case operator
        when '*' then repetition_within_limit?(value, operand)
        when '**' then power_within_limit?(value, operand)
        when '%' then value.is_a?(Numeric) # `String#%` is `format`, which can build a huge string
        else true
        end
      end

      # Repeating a string or array by an integer multiplies its size. (`Array#*` with a string joins instead.)
      def repetition_within_limit?(value, operand)
        return true unless operand.is_a?(Integer) && (value.is_a?(String) || value.is_a?(Array))

        operand >= 0 && value.size * operand <= MAX_REPEAT_SIZE
      end

      # A float overflows to Infinity at once. An integer power is only allowed if its result fits in MAX_POWER_BITS,
      # estimated as the bit length of the base times the exponent. Any other kind of number is not allowed.
      def power_within_limit?(value, operand)
        case value
        when Integer then operand.is_a?(Integer) && value.abs.bit_length * operand.abs <= MAX_POWER_BITS
        when Float then true
        else false
        end
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
