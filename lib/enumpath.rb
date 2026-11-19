# frozen_string_literal: true

require 'mini_cache'
require 'enumpath/logger'
require 'enumpath/operator'
require 'enumpath/path'
require 'enumpath/results'
require 'enumpath/resolver/object_inspector'
require 'enumpath/resolver/simple'
require 'enumpath/resolver/property'
require 'enumpath/version'

# A JSONPath-compatible library for navigating Ruby objects using path expressions
module Enumpath
  @verbose = false

  class << self
    # Whether verbose mode is enabled. When enabled, the {Enumpath::Logger} will print
    # information to the logging stream to assist in debugging path expressions.
    # Defaults to false
    #
    # @return [true,false]
    attr_accessor :verbose

    # Resolve a path expression against an enumerable
    #
    # @param path (see Enumpath::Path#initialize)
    # @param enum (see Enumpath::Path#apply)
    # @param options [optional, Hash]
    # @option options [Symbol] :result_type (:value) The type of results to return, `:value` or `:path`
    # @option options [true, false] :verbose (false) Whether to enable additional output for debugging
    # @option options [Symbol, #call] :property_resolver (:safe) Which methods a path may call on an object when a
    #   segment is not an index, key, or member: `:safe` (read-only methods only), `:none`, `:all` (any public method
    #   that expects no arguments, the behavior of version 0.1), or a callable `->(object, name) { ... }` that returns
    #   true to allow the call. Applies only to this call; a chained {Enumpath::Results#apply} uses the default unless
    #   the option is passed again. See {Enumpath::Resolver::Property}.
    # @raise [ArgumentError] if `:property_resolver` is not one of the values above
    # @return (see Enumpath::Path#apply)
    def apply(path, enum, options = {})
      logger.level = 0
      @verbose = options[:verbose] || false
      Enumpath::Resolver::Property.with_policy(options[:property_resolver]) do
        Enumpath::Path.new(path, result_type: options[:result_type]).apply(enum)
      end
    end

    # The {Enumpath::Logger} instance to use with verbose mode
    #
    # @private
    # @return [Enumpath::Logger]
    def logger
      @logger ||= Enumpath::Logger.new
    end

    # A shortcut to {Enumpath::logger.log}
    #
    # @private
    # @see Enumpath::Logger#log
    def log(title)
      block_given? ? logger.log(title, &-> { yield }) : logger.log(title)
    end

    # A lightweight in-memory cache for caching normalized path expressions
    #
    # @private
    # @return [MiniCache::Store]
    def path_cache
      @path_cache ||= MiniCache::Store.new
    end
  end
end
