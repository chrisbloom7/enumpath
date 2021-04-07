# frozen_string_literal: true

require 'mini_cache'
require 'enumpath/logger'
require 'enumpath/operator'
require 'enumpath/path'
require 'enumpath/results'
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
    # @return (see Enumpath::Path#apply)
    def apply(path, enum, options = {})
      logger.level = 0
      @verbose = options.delete(:verbose) || false
      Enumpath::Path.new(path, result_type: options.delete(:result_type)).apply(enum)
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
