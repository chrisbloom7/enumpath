# frozen_string_literal: true

module Enumpath
  module Operator
    # Abstract base class for Operator definitions. Provides some helper methods for each operator and defines the
    # basic factory methods that must be implemented.
    #
    # @abstract Subclass and override {.detect?} and {#apply} to implement a new path expression operator.
    class Base
      class << self
        # Provides an interface for determining if a given string represents the operator class
        #
        # @abstract Override in each path expression operator subclass
        #
        # @param operator [String] the the full, normalized operator to test
        # @param enum [Enumerable] an enum that can be used to assist in detection. Not all subclasses require an enum
        #   for detection.
        # @return [true, false] whether the operator param appears to represent the operator class
        def detect?(operator, enum = nil)
          raise NotImplementedError
        end
      end

      # @return [String] the full, normalized operator
      attr_reader :operator

      # Initializes an operator class with an operator string
      #
      # @param operator [String] the the full, normalized operator
      def initialize(operator)
        @operator = operator
      end

      # Provides an interface for applying the operator to a given enumerable and yielding that result back to the
      # caller with updated arguments
      #
      # @abstract Override in each path expression operator subclass
      #
      # @param remaining_path [Array] an array containing the normalized path segments yet to be resolved
      # @param enum [Enumerable] the object to apply the operator to
      # @param resolved_path [Array] an array containing the static path segments that have been resolved
      #
      # @yield A block that will be called if the operator is applied successfully. If the operator cannot or should
      #   not be applied then the block is not yielded.
      #
      # @yieldparam remaining_path [Array] the new remaining_path after applying the operator
      # @yieldparam enum [Enumerable] the new enum after applying the operator
      # @yieldparam resolved_path [Array] the new resolved_path after applying the operator
      # @yieldreturn [void]
      def apply(remaining_path, enum, resolved_path)
        raise NotImplementedError
      end

      # An alias to {#operator}, used by {Enumpath::Logger}
      #
      # @private
      # @return [String] the operator the class was initialized with
      def to_s
        operator
      end

      private

      # Returns a set of keys, member names, or indices for a given enumerable. Useful for operators that need to
      # iterate over each member of an enumerable.
      #
      # - Arrays return their indexes, Hashes their keys, and Structs and Data objects their member names. These are
      #   read through Ruby's own implementations, so a subclass that overrides them is not called.
      # - Any other object returns the keys of its `to_h`, but only if the current property resolver policy (see
      #   {Enumpath::Resolver::Property}) allows calling `to_h` and it returns a Hash. Under the default `:safe`
      #   policy a plain object's own `to_h` is never called, so iterating over it cannot run its code or consume an
      #   Enumerator.
      # - Everything else returns an empty array.
      #
      # @param enum [Enumerable] the object to detect keys, member names, or indices on.
      # @return [Array] a set of keys, member names, or indices for the object, or an empty set if they could not be
      #   determined.
      def keys(enum)
        core_keys = core_keys(enum)
        return core_keys unless core_keys.nil?

        hash = Enumpath::Resolver::Property.resolve('to_h', enum)
        hash.is_a?(Hash) ? hash.keys : []
      end

      def core_keys(enum)
        if enum.is_a?(Array)
          (0...Array.instance_method(:length).bind(enum).call).to_a
        elsif enum.is_a?(Hash)
          Hash.instance_method(:keys).bind(enum).call
        elsif enum.is_a?(Struct)
          Struct.instance_method(:members).bind(enum).call
        elsif Enumpath::Resolver::Simple.data?(enum)
          Enumpath::Resolver::Simple.data_members(enum)
        end
      end
    end
  end
end
