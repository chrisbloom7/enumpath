# frozen_string_literal: true

module Enumpath
  module Resolver
    # A utility for resolving a string as an index, key, or member of an enumerable
    class Simple
      NUMERIC_INDEX_TEST = /\A\-?(?:0|[1-9][0-9]*)\z/

      # Ruby's `Data` class (3.2 and later), or nil on older Rubies. Older Rubies have an unrelated, deprecated `Data`
      # constant, so it is only looked up on 3.2 and later.
      DATA_CLASS = ((RUBY_VERSION.split('.').map(&:to_i) <=> [3, 2]) >= 0 ? Object.const_get(:Data) : nil)

      class << self
        # Attempts to resolve a string as an index, key, or member of an enumerable. Members of `Data` objects
        # (Ruby 3.2 and later) resolve like Struct members.
        #
        # @param variable [String] the value to attempt to resolve
        # @param enum [Enumerable] the enumerable to resolve the value against
        # @return the resolved value, or nil if it could not be resolved
        def resolve(variable, enum)
          variable = variable.to_s
          value = rescued_dig(enum, variable.to_i) if variable =~ NUMERIC_INDEX_TEST
          value = rescued_dig(enum, variable) if value.nil?
          value = rescued_dig(enum, variable.to_sym) if value.nil?
          value = data_member(enum, variable) if value.nil?
          value
        end

        # Whether an object is a `Data` object (Ruby 3.2 and later)
        #
        # @private
        # @param object [Object]
        # @return [true, false]
        def data?(object)
          !DATA_CLASS.nil? && Kernel.instance_method(:is_a?).bind(object).call(DATA_CLASS)
        rescue TypeError
          false
        end

        # The member names of a `Data` object, read without calling any method the object's class defines
        #
        # @private
        # @param object [Data]
        # @return [Array<Symbol>]
        def data_members(object)
          DATA_CLASS.instance_method(:members).bind(object).call
        end

        private

        # Reads a member of a `Data` object through Data#to_h, which reads the stored values directly, so a member
        # reader overridden in the class is not called
        def data_member(enum, variable)
          return unless data?(enum) && data_members(enum).include?(variable.to_sym)

          DATA_CLASS.instance_method(:to_h).bind(enum).call[variable.to_sym]
        end

        def rescued_dig(enum, typecast_variable)
          enum.dig(typecast_variable)
        rescue NoMethodError, TypeError
          nil
        end
      end
    end
  end
end
