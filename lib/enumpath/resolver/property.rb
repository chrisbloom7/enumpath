# frozen_string_literal: true

module Enumpath
  module Resolver
    # A utility for resolving a string as a property (a public method that expects no arguments) of an object.
    #
    # Whether a method may be called is decided by a property resolver policy, set with the `:property_resolver`
    # option of {Enumpath.apply}:
    #
    # - `:safe` (the default): call a method only if it is known to be read-only. See {.safe?}.
    # - `:none`: never call methods. Indexes, keys and Struct members still resolve through {Resolver::Simple}.
    # - `:all`: call any public method that expects no arguments. This was the behavior of version 0.1 and lets a
    #   path run mutating or destructive methods such as `clear`, `pop` or `destroy`. Only use it with trusted paths.
    # - a callable (anything that responds to `call`, such as a lambda): called as `callable.call(object, name)` with
    #   the property name as a String; the method is called only when it returns a truthy value. The callable has
    #   full control: none of the identifier, arity or allowlist checks of `:safe` are applied.
    #
    # The policy for the current {Enumpath.apply} call is kept in a fiber-local variable (`Thread.current`), so it
    # reaches every operator without being passed through each one, and calls running in other threads or fibers do
    # not see it. Outside of {Enumpath.apply}, and in a chained {Enumpath::Results#apply} that does not pass the
    # option again, the default (`:safe`) applies.
    class Property
      # The policies accepted by the `:property_resolver` option, besides a callable
      POLICIES = %i[safe none all].freeze

      # The policy used when none is given
      DEFAULT_POLICY = :safe

      # Property names `:safe` will consider: plain identifiers, optionally ending in `?`. Names ending in `!` or
      # `=`, operators and constant-like names are never called.
      IDENTIFIER = /\A[a-z_][A-Za-z0-9_]*\??\z/.freeze

      # Read-only methods `:safe` calls on {SAFE_RECEIVERS}. Each returns a new value and leaves the receiver
      # unchanged on every core class that defines it. Mutating methods (`clear`, `pop`, `shift`, `delete`, `freeze`,
      # any `!` method) are deliberately absent.
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
      # input, so they only resolve attr_readers (see {.safe?}). Range is left out because methods like `sum` and
      # `sort` never return on an endless range.
      SAFE_RECEIVERS = [Array, Hash, String, Symbol, Numeric, NilClass, TrueClass, FalseClass, Struct].freeze

      # Modules whose implementation of a {SAFE_METHODS} name is trusted. A subclass of a {SAFE_RECEIVERS} class that
      # overrides one of these methods is not trusted.
      CORE_OWNERS = (SAFE_RECEIVERS + [Kernel, Comparable, Enumerable, Integer, Float, Rational, Complex]).freeze

      # Objects of these classes are never treated as plain Ruby objects, so their instance variables do not make a
      # method callable under `:safe`. Modules and classes are included because their instance variables are usually
      # internal state (memoized values, configuration), not data.
      CORE_CLASSES = (SAFE_RECEIVERS + [Range, Module, Proc, Method, UnboundMethod, IO, Enumerator, Thread]).freeze

      # The `Thread.current` key that holds the policy for the current {Enumpath.apply} call
      THREAD_KEY = :enumpath_property_resolver

      class << self
        # Attempts to resolve a string as a property of an object. In this context a property is a public method that
        # expects no arguments and that the policy allows.
        #
        # @param property [String] the name of the property to attempt to resolve
        # @param object [Object] the object to resolve the property against
        # @param policy [Symbol, #call] the property resolver policy to apply; defaults to {.current_policy}
        # @return the resolved property value, or nil if it could not be resolved or the policy does not allow it
        def resolve(property, object, policy = current_policy)
          name = property.to_s
          return unless allowed?(policy, object, name)

          object.public_send(name.to_sym)
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

        # Whether the `:safe` policy allows calling a method on an object. All of these must hold:
        #
        # - the name is a plain identifier (see {IDENTIFIER});
        # - the object publicly responds to it and the method has no required arguments;
        # - and either
        #   - the name is in {SAFE_METHODS}, the object is one of {SAFE_RECEIVERS}, and the method is Ruby's own
        #     (owned by one of {CORE_OWNERS}, not overridden); or
        #   - the object is not one of {CORE_CLASSES} and has an instance variable of the same name (`@name` for
        #     `name`), as an attr_reader on a plain Ruby object does.
        #
        # Struct members are not handled here: they resolve as members through {Resolver::Simple}.
        #
        # A callable policy can build on this check to allow more methods while keeping the safe ones:
        #
        # @example Keep the safe defaults and also allow ActiveRecord attribute readers
        #   readers = lambda do |object, name|
        #     Enumpath::Resolver::Property.safe?(object, name) ||
        #       (object.is_a?(ActiveRecord::Base) && object.class.attribute_names.include?(name))
        #   end
        #   Enumpath.apply('[?(@.published)].title', posts, property_resolver: readers)
        #
        # @param object [Object] the object to call the method on
        # @param name [String] the method name
        # @return [true, false]
        def safe?(object, name)
          return false unless name.match?(IDENTIFIER)

          method = public_method_without_required_args(object, name)
          return false if method.nil?

          core_reader?(object, name, method) || instance_variable_reader?(object, name)
        end

        private

        def allowed?(policy, object, name)
          case policy
          when :all then true
          when :none then false
          when :safe then safe?(object, name)
          else policy.call(object, name) ? true : false
          end
        end

        def validate_policy!(policy)
          return policy if POLICIES.include?(policy) || policy.respond_to?(:call)

          raise ArgumentError,
                "Invalid property_resolver #{policy.inspect}: use :safe, :none, :all, or a callable " \
                'that accepts (object, name)'
        end

        def public_method_without_required_args(object, name)
          return unless object.respond_to?(name)

          # Look the method up through Kernel so an object that overrides #method cannot get in the way
          method = Kernel.instance_method(:method).bind(object).call(name)
          method unless method.parameters.any? { |type, _| %i[req keyreq].include?(type) }
        rescue NameError, TypeError
          nil
        end

        def core_reader?(object, name, method)
          SAFE_METHODS.include?(name) &&
            SAFE_RECEIVERS.any? { |klass| object.is_a?(klass) } &&
            CORE_OWNERS.include?(method.owner)
        end

        def instance_variable_reader?(object, name)
          return false if name.end_with?('?')
          return false if CORE_CLASSES.any? { |klass| object.is_a?(klass) }

          object.instance_variable_defined?("@#{name}")
        end
      end
    end
  end
end
