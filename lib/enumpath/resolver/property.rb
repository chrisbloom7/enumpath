# frozen_string_literal: true

module Enumpath
  module Resolver
    # A utility for resolving a string as a property (a public method that expects no arguments) of an object.
    #
    # Which properties resolve is decided by a property resolver policy, set with the `:property_resolver` option of
    # {Enumpath.apply}:
    #
    # - `:safe` (the default): read-only access only. See {.safe?}.
    # - `:readers`: `:safe`, plus public methods written in Ruby (including those of installed gems) and
    #   ActiveModel-style `attributes`. See {.reader?}. This runs application and gem code and is not read-only.
    # - `:none`: never call methods. Indexes, keys and Struct or Data members still resolve through
    #   {Resolver::Simple}.
    # - `:all`: call any public method that expects no arguments. This was the behavior of version 0.1 and lets a
    #   path run mutating or destructive methods such as `clear`, `pop` or `destroy`. Only use it with trusted paths.
    # - a callable (anything that responds to `call`, such as a lambda): called as `callable.call(object, name)` with
    #   the property name as a String; the method is called only when it returns a truthy value. The callable has
    #   full control: none of the checks of the other policies are applied. It can call {.safe?} or {.reader?} to
    #   build on them.
    #
    # The policy for the current {Enumpath.apply} call is kept in a fiber-local variable (`Thread.current`), so it
    # reaches every operator without being passed through each one, and calls running in other threads or fibers do
    # not see it. Outside of {Enumpath.apply}, and in a chained {Enumpath::Results#apply} that does not pass the
    # option again, the default (`:safe`) applies.
    class Property
      # The policies accepted by the `:property_resolver` option, besides a callable
      POLICIES = %i[safe readers none all].freeze

      # The policy used when none is given
      DEFAULT_POLICY = :safe

      # Property names `:safe` and `:readers` will consider: plain identifiers, optionally ending in `?`. Names ending
      # in `!` or `=`, operators and constant-like names are never called.
      IDENTIFIER = /\A[a-z_][A-Za-z0-9_]*\??\z/.freeze

      # Read-only methods `:safe` calls on {SAFE_RECEIVERS}. Each returns a new value and leaves the receiver
      # unchanged in Ruby's own implementation. Mutating methods (`clear`, `pop`, `shift`, `delete`, `freeze`, any `!`
      # method) are deliberately absent.
      SAFE_METHODS = %w[
        length size count empty? any? all? none? one?
        first last min max minmax sum
        keys values entries to_a to_h
        reverse compact sort uniq flatten
        to_s to_sym to_i to_f to_r to_c
        nil? zero? nonzero? positive? negative? even? odd? finite? infinite? integer?
        abs floor ceil round truncate next pred succ
        upcase downcase capitalize swapcase strip lstrip rstrip chomp chop bytesize
      ].freeze

      # The plain data classes on which `:safe` calls {SAFE_METHODS}. Other objects that define methods with the same
      # names (an IO, an Enumerator, a database relation, a custom collection) could run arbitrary code or consume
      # input. Range is left out because methods like `sum` and `sort` never return on an endless range.
      SAFE_RECEIVERS = ([Array, Hash, String, Symbol, Numeric, NilClass, TrueClass, FalseClass, Struct] +
                        [Simple::DATA_CLASS].compact).freeze

      # Modules whose implementation of a {SAFE_METHODS} name is trusted. A subclass of a {SAFE_RECEIVERS} class that
      # overrides one of these methods is not trusted.
      CORE_OWNERS = (SAFE_RECEIVERS + [Kernel, Comparable, Enumerable, Integer, Float, Rational, Complex]).freeze

      # Instances of these classes are core objects: their instance variables never make a property resolvable, and
      # `:readers` treats them exactly like `:safe`. Modules and classes are included because their instance
      # variables are usually internal state (memoized values, configuration), not data.
      CORE_CLASSES = (SAFE_RECEIVERS + [Range, Module, Proc, Method, UnboundMethod, IO, Enumerator, Thread]).freeze

      # Common persistence verbs `:readers` refuses to call even when the object's class defines them. This is a
      # safety net for ActiveRecord-style models, not a guarantee: `:readers` still runs any other public method that
      # expects no arguments.
      READERS_DENYLIST = %w[destroy delete save update reload touch delete_all destroy_all toggle].freeze

      # The `Thread.current` key that holds the policy for the current {Enumpath.apply} call
      THREAD_KEY = :enumpath_property_resolver

      class << self
        # Attempts to resolve a string as a property of an object, as the policy allows
        #
        # @param property [String] the name of the property to attempt to resolve
        # @param object [Object] the object to resolve the property against
        # @param policy [Symbol, #call] the property resolver policy to apply; defaults to {.current_policy}
        # @return the resolved property value, or nil if it could not be resolved or the policy does not allow it
        def resolve(property, object, policy = current_policy)
          access(policy, object, property.to_s)&.call
        rescue ArgumentError, NoMethodError, TypeError, RangeError
          nil
        end

        # The policy for the current {Enumpath.apply} call in this thread or fiber
        #
        # @return [Symbol, #call] the current policy, or {DEFAULT_POLICY} when none is set
        def current_policy
          Thread.current[THREAD_KEY] || DEFAULT_POLICY
        end

        # Runs the block with a policy as the {.current_policy}, then restores the previous policy, even if the block
        # raises. Used by {Enumpath.apply}.
        #
        # @private
        # @param policy [Symbol, #call, nil] the policy to use; nil means {DEFAULT_POLICY}
        # @raise [ArgumentError] if the policy is not valid
        # @return the value of the block
        def with_policy(policy)
          policy = validate_policy!(policy.nil? ? DEFAULT_POLICY : policy)
          previous = Thread.current[THREAD_KEY]
          Thread.current[THREAD_KEY] = policy
          begin
            yield
          ensure
            Thread.current[THREAD_KEY] = previous
          end
        end

        # Whether the `:safe` policy resolves a property of an object. All of these must hold:
        #
        # - the name is a plain identifier (see {IDENTIFIER});
        # - the object publicly responds to it and the method has no required arguments;
        # - and either
        #   - the name is in {SAFE_METHODS}, the object is one of {SAFE_RECEIVERS}, and the method is Ruby's own
        #     (owned by one of {CORE_OWNERS}, not overridden), in which case the method is called; or
        #   - the object is not one of {CORE_CLASSES} and has an instance variable of the same name (`@name` for
        #     `name`), as an attr_reader on a plain Ruby object does. In that case the instance variable is read
        #     directly and the method itself is never called, so a method that merely shares its name with an
        #     instance variable cannot run.
        #
        # Struct and Data members are not handled here: they resolve as members through {Resolver::Simple}.
        #
        # A callable policy can build on this check to allow more methods while keeping the safe ones:
        #
        # @example Keep the safe defaults and also allow one method of your own
        #   policy = lambda do |object, name|
        #     Enumpath::Resolver::Property.safe?(object, name) || (object.is_a?(Invoice) && name == 'total')
        #   end
        #   Enumpath.apply('invoices.*.total', account, property_resolver: policy)
        #
        # @param object [Object] the object to read from
        # @param name [String] the property name
        # @return [true, false]
        def safe?(object, name)
          !safe_access(object, name).nil?
        rescue StandardError
          false
        end

        # Whether the `:readers` policy resolves a property of an object. Core objects (see {CORE_CLASSES}) are
        # treated exactly like {.safe?}. For any other object, either
        #
        # - the name is a plain identifier (see {IDENTIFIER}), not in {READERS_DENYLIST}, and the object publicly
        #   responds to it with a method that expects no arguments and is written in Ruby outside of Ruby itself (see
        #   {ObjectInspector.application_method?}), so computed readers like `full_name` work; or
        # - the object has an ActiveModel-style `attributes` method (no arguments, written in Ruby outside of Ruby
        #   itself) that returns a Hash with the name as a String key, so attributes like `email` work even before
        #   their reader methods are defined; or
        # - {.safe?} allows it.
        #
        # In short, `:readers` runs any public method that expects no arguments and is written in Ruby, except Ruby's
        # built-in methods, methods in the Ruby standard library directory, and {READERS_DENYLIST}. Methods
        # implemented in C (core classes, StringIO, C-extension gems) are never called; objects of C-extension classes
        # need a callable policy or `:all`. Methods from installed gems are called, including default and bundled gems
        # such as Logger and CSV, and ActiveModel or ActiveRecord: for example `Logger#close` would run.
        #
        # So `:readers` is not read-only. Use it for data you trust or objects you built. For untrusted paths use
        # `:safe`, or a callable that builds on {.safe?} with a per-class allowlist.
        #
        # @param object [Object] the object to read from
        # @param name [String] the property name
        # @return [true, false]
        def reader?(object, name)
          !reader_access(object, name).nil?
        rescue StandardError
          false
        end

        private

        # Each *access method returns nil when the property may not be resolved, or a lambda that resolves it
        def access(policy, object, name)
          case policy
          when :all then -> { object.public_send(name.to_sym) }
          when :none then nil
          when :safe then safe_access(object, name)
          when :readers then reader_access(object, name)
          else (-> { object.public_send(name.to_sym) } if policy.call(object, name))
          end
        end

        def safe_access(object, name)
          return unless name.match?(IDENTIFIER)

          method = ObjectInspector.public_method_without_required_args(object, name)
          return if method.nil?
          return -> { object.public_send(name.to_sym) } if core_reader?(object, name, method)

          instance_variable_access(object, name)
        end

        def reader_access(object, name)
          return safe_access(object, name) if ObjectInspector.instance_of_any?(object, CORE_CLASSES)
          return unless name.match?(IDENTIFIER)
          return if READERS_DENYLIST.include?(name)

          app_method_access(object, name) || attribute_access(object, name) || safe_access(object, name)
        end

        def app_method_access(object, name)
          method = ObjectInspector.public_method_without_required_args(object, name)
          return unless ObjectInspector.application_method?(method)

          -> { object.public_send(name.to_sym) }
        end

        def attribute_access(object, name)
          method = ObjectInspector.public_method_without_required_args(object, 'attributes')
          return unless ObjectInspector.application_method?(method)

          attributes = object.public_send(:attributes)
          -> { attributes[name] } if attributes.is_a?(Hash) && attributes.key?(name)
        end

        def validate_policy!(policy)
          return policy if POLICIES.include?(policy) || policy.respond_to?(:call)

          raise ArgumentError, "Invalid property_resolver #{policy.inspect}: use :#{POLICIES.join(', :')} or a callable"
        end

        def core_reader?(object, name, method)
          SAFE_METHODS.include?(name) &&
            ObjectInspector.instance_of_any?(object, SAFE_RECEIVERS) &&
            CORE_OWNERS.include?(method.owner)
        end

        def instance_variable_access(object, name)
          return if name.end_with?('?') || ObjectInspector.instance_of_any?(object, CORE_CLASSES)

          ivar = "@#{name}"
          return unless ObjectInspector.kernel(object, :instance_variable_defined?, ivar)

          -> { ObjectInspector.kernel(object, :instance_variable_get, ivar) }
        end
      end
    end
  end
end
