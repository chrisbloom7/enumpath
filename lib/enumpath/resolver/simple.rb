# frozen_string_literal: true

module Enumpath
  module Resolver
    class Simple
      NUMERIC_INDEX_TEST = /\A\-?(?:0|[1-9][0-9]*)\z/

      class << self
        # Precedence:
        # 1. Resolve to numeric index or key
        # 2. Resolve to string key
        # 3. Resolve to symbol key
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
