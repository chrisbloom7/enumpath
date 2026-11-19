# frozen_string_literal: true

require 'enumpath/logger'
require 'enumpath/operator'
require 'enumpath/path'
require 'enumpath/path_cache'
require 'enumpath/regexp_parser'
require 'enumpath/regexp_timeout'
require 'enumpath/results'
require 'enumpath/resolver/object_inspector'
require 'enumpath/resolver/simple'
require 'enumpath/resolver/property'
require 'enumpath/version'

# A JSONPath-compatible library for navigating Ruby objects using path expressions
module Enumpath
  # The `Thread.current` key that holds the `:verbose` option of the current {Enumpath.apply} call
  VERBOSE_KEY = :enumpath_verbose

  # The process-wide default for verbose mode
  @verbose = false
  # How many {Enumpath.apply} calls are running with a `:verbose` option. While it is zero, {Enumpath.verbose} is just
  # the default, without a look at the thread's own setting, which keeps the common case fast.
  @verbose_overrides = 0
  @verbose_lock = Mutex.new
  # The logger and the path cache are created when Enumpath loads, so threads never race to create them
  @logger = Enumpath::Logger.new
  @path_cache = Enumpath::PathCache.new

  class << self
    # Sets whether verbose mode is on by default, for every call that does not pass a `:verbose` option. Set this once
    # at start up; to change it for one call, or one thread, pass the `:verbose` option to {Enumpath.apply}.
    #
    # @param value [true, false] the default
    attr_writer :verbose

    # Whether verbose mode is enabled. When enabled, the {Enumpath::Logger} will print
    # information to the logging stream to assist in debugging path expressions. During an {Enumpath.apply} call this
    # is the call's `:verbose` option, if it has one, and only in that call's thread; otherwise it is the default set
    # with {Enumpath.verbose=}. Defaults to false
    #
    # @return [true,false]
    def verbose
      return @verbose if @verbose_overrides.zero?

      override = Thread.current[VERBOSE_KEY]
      override.nil? ? @verbose : override
    end

    # Resolve a path expression against an enumerable
    #
    # @param path (see Enumpath::Path#initialize)
    # @param enum (see Enumpath::Path#apply)
    # @param options [optional, Hash]
    # @option options [Symbol] :result_type (:value) The type of results to return, `:value` or `:path`
    # @option options [true, false] :verbose (Enumpath.verbose) Whether to enable additional output for debugging, for
    #   this call only
    # @option options [Symbol, #call] :property_resolver (:safe) Which methods a path may call on an object when a
    #   segment is not an index, key, or member: `:safe` (read-only methods only), `:readers` (`:safe` plus public
    #   no-argument methods written in Ruby, including those of installed gems, and ActiveModel-style `attributes`;
    #   not read-only, for trusted data only), `:none`, `:all` (any public method that expects no arguments, the
    #   behavior of version 0.1), or a callable `->(object, name) { ... }` that returns true to allow the call.
    #   Applies only to this call; a chained {Enumpath::Results#apply} uses the default unless the option is passed
    #   again. See {Enumpath::Resolver::Property}.
    # @option options [Numeric, nil] :regexp_timeout (1.0) The most seconds a regular expression in a filter may take to
    #   match, or nil for no limit. A match that runs out of time does not match, and so do the regular expressions
    #   after it in the same call. Needs Ruby 3.2 or later; older Rubies ignore it. See
    #   {Enumpath::RegexpTimeout}.
    # @raise [ArgumentError] if `:property_resolver` is not one of the values above, or `:regexp_timeout` is not nil or
    #   a positive number
    # @return (see Enumpath::Path#apply)
    def apply(path, enum, options = {})
      with_verbose(options[:verbose]) do
        logger.level = 0 if verbose
        Enumpath::Resolver::Property.with_policy(options[:property_resolver]) do
          Enumpath::RegexpTimeout.with_limit(options.fetch(:regexp_timeout, Enumpath::RegexpTimeout::DEFAULT)) do
            Enumpath::Path.new(path, result_type: options[:result_type]).apply(enum)
          end
        end
      end
    end

    # The {Enumpath::Logger} instance to use with verbose mode
    #
    # @private
    # @return [Enumpath::Logger]
    attr_reader :logger

    # A shortcut to {Enumpath::logger.log}
    #
    # @private
    # @see Enumpath::Logger#log
    def log(title)
      return unless verbose

      block_given? ? logger.log(title, &-> { yield }) : logger.log(title)
    end

    # A bounded in-memory cache for normalized path expressions that threads can share
    #
    # @private
    # @return [Enumpath::PathCache]
    attr_reader :path_cache

    private

    # Runs the block with the call's `:verbose` option in effect for this thread, then restores the previous value,
    # even if the block raises. A nil option leaves the setting alone.
    def with_verbose(option)
      return yield if option.nil?

      @verbose_lock.synchronize { @verbose_overrides += 1 }
      previous = Thread.current[VERBOSE_KEY]
      Thread.current[VERBOSE_KEY] = option ? true : false
      begin
        yield
      ensure
        Thread.current[VERBOSE_KEY] = previous
        @verbose_lock.synchronize { @verbose_overrides -= 1 }
      end
    end
  end
end
