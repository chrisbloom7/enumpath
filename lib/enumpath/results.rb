# frozen_string_literal: true

# TODO: Consider adding support for other return types?
#   - dig compatible array with typecast keys
#   - dot-notation style path for Enumpath

module Enumpath
  # An Array-like structure with syntactical sugar for storing the results of evaluating a path expression against an
  # enumerable.
  class Results < Array
    RESULT_TYPE_PATH = :path
    RESULT_TYPE_VALUE = :value

    # @return [Symbol] the current result type
    attr_reader :result_type

    # @param result_type [Symbol] the type of result to store, :value (default) or :path
    def initialize(result_type: RESULT_TYPE_VALUE)
      @result_type = result_type
      super()
    end

    # Resolve a new path expression against the results of the last path expression
    #
    # @param path (see Enumpath.apply)
    # @param options (see Enumpath.apply)
    # @return (see Enumpath.apply)
    def apply(path, options = {})
      Enumpath.apply(path, self, options)
    end

    # Adds a new result to the collection, the format of which is determined by the value of @result_type
    #
    # @param resolved_path [Array] the path segments leading to the resolved value
    # @param value the resolved value
    # @return [self]
    def store(resolved_path, value)
      result = if result_type == RESULT_TYPE_PATH
                 as_path(resolved_path)
               else
                 value
               end
      Enumpath.log('New Result') { { result: result } }
      push(result)
    end

    private

    def as_path(resolved_path)
      path = [Enumpath::Operator::ROOT]
      resolved_path.each do |segment|
        path << %([#{segment.to_s =~ /^[0-9*]+$/ ? segment : "'#{segment}'"}])
      end
      path.join('')
    end
  end
end
