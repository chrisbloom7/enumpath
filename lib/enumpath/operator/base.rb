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

      def apply(remaining_segments, enum, current_path, &block)
        raise NotImplementedError
      end

      def to_s
        operator
      end

      private

      def keys(enum)
        # Arrays
        return enum.each_with_index.to_h.values if enum.is_a?(Array)

        # Other Enumerables
        return enum.to_h.keys if enum.respond_to?(:to_h)

        # Fallback
        []
      end
    end
  end
end
