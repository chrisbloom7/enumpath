# frozen_string_literal: true

# Implements JSONPath recursive descent operator syntax

module Enumpath
  module Operator
    class RecursiveDescent < Base
      OPERATOR = '..'

      class << self
        def detect?(operator)
          !!(operator == OPERATOR)
        end
      end

      def apply(remaining_path, enum, resolved_path, &block)
        Enumpath.log('Applying remaining path recursively to enum') { { 'remaining path': remaining_path } }
        yield(remaining_path, enum, resolved_path)
        keys(enum).each do |key|
          value = Enumpath::Resolver::Simple.resolve(key, enum)
          if recursable?(value)
            Enumpath.log('Applying remaining path recursively to key') do
              { key: key, 'remaining path': ['..'] + remaining_path }
            end
            yield(['..'] + remaining_path, value, resolved_path + [key])
          end
        end
      end

      private

      def recursable?(value)
        value.is_a?(Enumerable)
      end
    end
  end
end
