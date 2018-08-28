# frozen_string_literal: true

module Enumpath
  module Operator
    class Base
      class << self
        def detect?(operator)
          raise NotImplementedError
        end
      end

      attr_reader :operator

      def initialize(operator)
        @operator = operator
      end

      def apply(remaining_path, enum, resolved_path, &block)
        raise NotImplementedError
      end

      def to_s
        operator
      end

      private

      def keys(object)
        # Arrays
        return (0...object.length).to_a if object.is_a?(Array)

        # Other Enumerables
        return object.to_h.keys if object.respond_to?(:to_h)

        # Fallback
        []
      end
    end
  end
end
