# frozen_string_literal: true

module Enumpath
  class Results < Array
    # TODO: COnsider adding support for other return types?
    #       - dig compatible array with typecast keys
    #       - dot-notation style path for Enumpath
    RESULT_TYPE_PATH = :path
    RESULT_TYPE_VALUE = :value

    attr_reader :result_type

    def initialize(result_type: nil)
      @result_type = result_type || RESULT_TYPE_VALUE
      super()
    end

    def store(current_path, enum)
      value = if result_type == RESULT_TYPE_PATH
                as_path(current_path)
              else
                enum
              end
      Enumpath.log('New Result') { { result: value } }
      push(result_type == RESULT_TYPE_PATH ? as_path(current_path) : enum)
      return last
    end

    def apply(path, options = {})
      Enumpath.apply(path, self, options)
    end

    private

    def as_path(current_path)
      path = [Enumpath::Operator::ROOT]
      current_path.each do |segment|
        path << %([#{segment.to_s =~ /^[0-9*]+$/ ? segment : "'#{segment}'"}])
      end
      path.join('')
    end
  end
end
