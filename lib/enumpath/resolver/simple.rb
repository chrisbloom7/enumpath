# frozen_string_literal: true

module Enumpath
  module Resolver
    # A utility for resolving a string as an index, key, or member of an enumerable
    class Simple
      NUMERIC_INDEX_TEST = /\A\-?(?:0|[1-9][0-9]*)\z/

      class << self
        # Attempts to resolve a string as an index, key, or member of an enumerable
        #
        # @param variable [String] the value to attempt to resolve
        # @param enum [Enumerable] the enumerable to resolve the value against
        # @return the resolved value, or nil if it could not be resolved
        def resolve(variable, enum)
          variable = variable.to_s
          value = rescued_dig(enum, variable.to_i) if variable =~ NUMERIC_INDEX_TEST
          value = rescued_dig(enum, variable) if value.nil?
          value = rescued_dig(enum, variable.to_sym) if value.nil?
          value
        end

        private

        def rescued_dig(enum, typecast_variable)
          enum.dig(typecast_variable)
        rescue NoMethodError, TypeError
          nil
        end
      end
    end
  end
end
