# frozen_string_literal: true

require 'enumpath/path/normalized'
require 'enumpath/path/resolved'

module Enumpath
  # A mechanism for applying path expressions to enumerables and tracking results
  class Path
    # @return [Enumpath::Path::Normalized] the normalized path
    attr_reader :path

    # @return [Enumpath::Results] the current results array
    attr_reader :results

    # @param path [String, Array<String>] the path expression to apply to the enumerable
    # @param result_type (see Enumpath::Results#initialize)
    def initialize(path, result_type: nil)
      @path = path
      normalize!
      @results = Enumpath::Results.new(result_type: result_type)
    end

    # Apply the path expression against an enumerable
    #
    # @note Calling this method resets the previous results array
    #
    # @param enum [Enumerable] the enumerable to apply the path to
    # @return [Enumpath::Results] an array of resolved values or paths
    def apply(enum)
      results.clear
      trace(@path.dup, enum)
      results
    end

    private

    # Applies the next normalized path segment to enumerable and keeps track of resolved path segments. This method
    # recursively yields to itself via each Operator subclass's {#apply} method. If there are no remaining path
    # segments then it stores a new result in the results array effectively ending processing on that branch of the
    # original enumerator.
    #
    # @param path_segments [Array] an array containing the normalized path segments to be resolved
    # @param enum [Enumerable] the object to apply the next normalized path segment to
    # @param resolved_path [Array] an array containing the static path segments that have been resolved so far
    # @param nesting_level [Integer] used to set the indentation level for {Enumpath::Logger}
    # @return [void]
    def trace(path_segments, enum, resolved_path = [], nesting_level = 0)
      Enumpath.logger.level = nesting_level
      if path_segments.any?
        Enumpath.log('Applying') { { operator: path_segments, to: enum } }
        apply_segments(path_segments, enum, resolved_path, nesting_level)
      else
        Enumpath.log('Storing') { { resolved_path: resolved_path, enum: enum } }
        results.store(resolved_path, enum)
      end
      Enumpath.logger.level = nesting_level
    end

    def apply_segments(path_segments, enum, resolved_path, nesting_level)
      segment = path_segments.first
      remaining_path = path_segments[1..-1]
      operator = Enumpath::Operator.detect(segment, enum)
      operator&.apply(remaining_path, enum, resolved_path) do |s, e, c|
        trace(s, e, c, nesting_level + 1)
      end
    end

    def cache
      @cache ||= Enumpath.path_cache
    end

    def normalize!
      @path = cache.get_or_set(@path) { Enumpath::Path::Normalized.new(@path) }
    end
  end
end
