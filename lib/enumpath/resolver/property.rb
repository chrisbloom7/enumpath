# frozen_string_literal: true

module Enumpath
  module Resolver
    class Property
      NUMERIC_INDEX_TEST = /\A\-?(?:0|[1-9][0-9]*)\z/

      class << self
        def resolve(variable, enum)
          variable = variable.to_s
          rescued_public_send(enum, variable.to_sym)
        end

        private

        def rescued_public_send(enum, method_symbol)
          enum.public_send(method_symbol)
        rescue ArgumentError, NoMethodError
          nil
        end
      end
    end
  end
end
