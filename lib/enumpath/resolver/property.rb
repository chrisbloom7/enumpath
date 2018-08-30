# frozen_string_literal: true

module Enumpath
  module Resolver
    # A utility for resolving a string as a property of an object
    class Property
      class << self
        # Attempts to resolve a string as a property of an object. In this context a property is a public method that
        # expects no arguments.
        #
        # @param property [String] the name of the property to attempt to resolve
        # @param object [Object] the object to resolve the property against
        # @return the resolved property value, or nil if it could not be resolved
        def resolve(property, object)
          # TODO: return if Enumpath.disable_property_resolver
          object.public_send(property.to_s.to_sym)
        rescue ArgumentError, NoMethodError
          nil
        end
      end
    end
  end
end
