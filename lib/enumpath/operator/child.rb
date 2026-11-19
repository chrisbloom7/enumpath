# frozen_string_literal: true

module Enumpath
  module Operator
    # Implements JSONPath child operator syntax. See {file:README.md#label-Child+operator} for syntax and examples.
    class Child < Base
      class << self
        # Checks to see if an operator is valid as a child operator. It is considered valid if the enumerable contains
        # an index, key, member, or property that responds to child.
        #
        # @param operator (see Enumpath::Operator::Base.detect?)
        # @return (see Enumpath::Operator::Base.detect?)
        def detect?(operator, enum)
          !resolve(operator, enum).nil?
        end

        # Like {.detect?}, but returns a Child that keeps the value it resolved for {#apply}, or nil if the operator
        # does not resolve. Nothing is allocated for a segment that is not a child.
        #
        # @private
        # @param operator (see Enumpath::Operator::Base.detect?)
        # @param enum [Enumerable] the enumerable to resolve the operator against
        # @return [Enumpath::Operator::Child, nil]
        def detect(operator, enum)
          value = resolve(operator, enum)
          new(operator).tap { |child| child.keep(enum, value) } unless value.nil?
        end

        # @private
        def resolve(operator, enum)
          value = Enumpath::Resolver::Simple.resolve(operator, enum)
          value = Enumpath::Resolver::Property.resolve(operator, enum) if value.nil?
          value
        end
      end

      # @private
      def keep(enum, value)
        @detected = true
        @detected_enum = enum
        @detected_value = value
      end

      # Whether the operator resolves against an enumerable. The resolved value is kept, so a following {#apply} to
      # the same enumerable uses it instead of resolving the operator a second time. That matters when a property
      # resolver policy lets the operator call a method, which must run once per path segment.
      #
      # @param enum [Enumerable] the enumerable to resolve the operator against
      # @return [true, false] whether the operator resolved to a value
      def detect?(enum)
        keep(enum, self.class.resolve(operator, enum))
        !@detected_value.nil?
      end

      # Resolves a child operator against an enumerable. If the child operator matches a index, key, member, or
      # property of the enumerable it is yielded to the block.
      #
      # @param (see Enumpath::Operator::Base#apply)
      # @yield (see Enumpath::Operator::Base#apply)
      # @yieldparam remaining_path [Array] remaining_path
      # @yieldparam enum [Enumerable] the resolved value of the enumerable
      # @yieldparam resolved_path [Array] resolved_path plus the child operator
      def apply(remaining_path, enum, resolved_path)
        value = detected_value(enum)
        yield(remaining_path, value, resolved_path + [operator]) unless value.nil?
      end

      private

      # The value kept by {#detect?} if it was for this enumerable (used once), otherwise a fresh resolution
      def detected_value(enum)
        return self.class.resolve(operator, enum) unless @detected && @detected_enum.equal?(enum)

        value = @detected_value
        @detected = @detected_enum = @detected_value = nil
        value
      end
    end
  end
end
