# frozen_string_literal: true

module Enumpath
  class Path
    class NormalizedPath < Array
      FILTER_EXPRESSION_REGEX = /[\['](\??\(.*?\))[\]']/
      INDEX_NOTATION_REGEX = /#([0-9]+)/

      def initialize(path)
        super(normalize(path))
      end

      private

      def normalize(path)
        return path if path.is_a?(Array)
        normalized_path = path.dup
        normalized_path, filter_expressions = remove_filter_expressions(normalized_path)
        normalized_path.gsub!(/'?\.'?|\['?/, ';')    # Replace "'?.'?" or "['?" with ";"
        normalized_path.gsub!(/;;;|;;/, ';..;')      # Replace ";;;" or ";;" with ";..;"
        normalized_path.gsub!(/;\z|'?\]|'\z/, '')    # Replace ";$" or "'?]" or "'$" with ""
        normalized_path = restore_filter_expressions(normalized_path, filter_expressions)
        normalized_path.gsub!(/\A\$(;|\z)/, '')      # Remove root operator
        normalized_path = normalized_path.split(';') # Split into segment parts
        normalized_path.reject! do |segment|         # Get rid of any blank segments
          segment.nil? || segment.size == 0
        end
        Enumpath.log('Path normalized') { { original: path, normalized: normalized_path } }
        normalized_path
      end

      # Move filter expressions (`[?(expr)]`) to the temporary array and replace with an index notation
      def remove_filter_expressions(path)
        filter_expressions = []
        stripped_path = path.gsub(FILTER_EXPRESSION_REGEX) do
          filter_expressions << $1
          "[##{filter_expressions.size - 1}]"
        end
        [stripped_path, filter_expressions]
      end

      # Replace index notations with their corresponding filter expressions (`?(expr)`) from the temporary array
      def restore_filter_expressions(path_expression, filter_expressions)
        path_expression.gsub(INDEX_NOTATION_REGEX) { filter_expressions[$1.to_i] }
      end
    end
  end
end
