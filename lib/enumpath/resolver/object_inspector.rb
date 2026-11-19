# frozen_string_literal: true

require 'rbconfig'

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

      # Ruby's standard library directory (`RbConfig::CONFIG['rubylibdir']`). Installed gems, including default and
      # bundled gems such as Logger or CSV, live elsewhere and are not covered by it.
      RUBY_LIBRARY_DIR = File.join(RbConfig::CONFIG['rubylibdir'], '')

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

      # Whether `:readers` may call a method: it is written in Ruby (it has a source location, so it is not
      # implemented in C), it is not one of Ruby's built-in methods (`<internal:...>`), and it is not in the Ruby
      # standard library directory ({RUBY_LIBRARY_DIR}). Methods from installed gems pass this check, including
      # default and bundled gems such as Logger and CSV, and so do attr_readers and methods made with
      # `define_method` or `class_eval`.
      #
      # @param method [Method, nil]
      # @return [true, false]
      def application_method?(method)
        location = method&.source_location
        return false if location.nil? || location.empty?

        file = location.first.to_s
        !file.start_with?('<internal:') && !file.start_with?(RUBY_LIBRARY_DIR)
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
