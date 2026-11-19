# frozen_string_literal: true

module Enumpath
  module Resolver
    # Helpers for inspecting an object without trusting it. Kernel methods are called through
    # `Kernel.instance_method(...).bind`, so an object that overrides `is_a?`, `respond_to?`, `method` or the instance
    # variable methods cannot change the answer.
    #
    # @private
    module ObjectInspector
      # The Kernel methods {.kernel} can call
      KERNEL = %i[is_a? respond_to? method instance_variable_defined? instance_variable_get].map do |name|
        [name, Kernel.instance_method(name)]
      end.to_h.freeze

      module_function

      # Calls one of the {KERNEL} methods on an object
      #
      # @raise [TypeError] if the object does not include Kernel (a BasicObject)
      def kernel(object, method_name, *args)
        KERNEL[method_name].bind(object).call(*args)
      end

      # The public method of that name, if the object has one that expects no arguments
      #
      # @return [Method, nil]
      def public_method_without_required_args(object, name)
        return unless kernel(object, :respond_to?, name)

        method = kernel(object, :method, name)
        method unless method.parameters.any? { |type, _| %i[req keyreq].include?(type) }
      rescue NameError, TypeError
        nil
      end

      # Whether the object is an instance of any of the classes. Objects that do not include Kernel count as a match,
      # so callers treat them as off limits.
      #
      # @return [true, false]
      def instance_of_any?(object, classes)
        classes.any? { |klass| kernel(object, :is_a?, klass) }
      rescue TypeError
        true
      end
    end
  end
end
