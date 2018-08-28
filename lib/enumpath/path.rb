# frozen_string_literal: true

require 'enumpath/path/normalized_path'

module Enumpath
  class Path
    attr_reader :path, :results

    def initialize(path, result_type: nil)
      @path = path
      normalize!
      @results = Enumpath::Results.new(result_type: result_type)
    end

    # This deviates from the original JSONPath spec in that we don't return false if there are no results.
    # Instead we return the empty result set. This is a thoughtful divergence based on the Robustness Principle.
    def apply(enum)
      results.clear
      trace(@path.dup, enum)
      results
    end

    private

    def trace(path_segments, enum, resolved_path = [], nesting_level = 0)
      Enumpath.logger.level = nesting_level
      if path_segments.any?
        Enumpath.log("Applying") { { operator: path_segments, to: enum } }
        segment = path_segments.first
        remaining_path = path_segments[1..-1]
        operator = Enumpath::Operator.detect(segment, enum)
        operator&.apply(remaining_path, enum, resolved_path) do |s, e, c|
          trace(s, e, c, nesting_level + 1)
        end
      else
        Enumpath.log('Storing') { { resolved_path: resolved_path, enum: enum } }
        results.store(resolved_path, enum)
      end
      Enumpath.logger.level = nesting_level
    end

    private

    def cache
      @cache ||= Enumpath.path_cache
    end

    def normalize!
      @path = cache.get_or_set(@path) { Enumpath::Path::NormalizedPath.new(@path) }
    end
  end
end
