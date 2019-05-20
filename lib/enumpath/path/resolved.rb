# frozen_string_literal: true

module Enumpath
  class Path
    # A utility for automatically normalizing string path expressions
    class Resolved < Array
      FILTER_EXPRESSION_REGEX = /[\['](\??\(.*?\))[\]']/
      INDEX_NOTATION_REGEX = /#([0-9]+)/

      # @param path (see Enumpath::Path#initialize)
      def initialize(path)
        super(normalize(path))
      end

      private

      def normalize(path)
        return path if path.is_a?(Array)

        normalized_path = path.dup
        filter_expressions = remove_filter_expressions!(normalized_path)
        replace_tokens!(normalized_path)
        restore_filter_expressions!(normalized_path, filter_expressions)
        remove_root!(normalized_path)
        normalized_path = normalized_path.split(';') # Split into segment parts
        normalized_path.reject! { |segment| segment.nil? || segment.size.zero? } # Remove blanks
        Enumpath.log('Path normalized') { { original: path, normalized: normalized_path } }
        normalized_path
      end

      # Move filter expressions (`[?(expr)]`) to the temporary array and replace with an index notation
      def remove_filter_expressions!(path)
        filter_expressions = []
        path.gsub!(FILTER_EXPRESSION_REGEX) do
          filter_expressions << Regexp.last_match(1)
          "[##{filter_expressions.size - 1}]"
        end
        filter_expressions
      end

      def replace_tokens!(path)
        path.gsub!(/'?\.'?|\['?/, ';') # Replace "'?.'?" or "['?" with ";"
        path.gsub!(/;;;|;;/, ';..;')   # Replace ";;;" or ";;" with ";..;"
        path.gsub!(/;\z|'?\]|'\z/, '') # Replace ";$" or "'?]" or "'$" with ""
      end

      # Replace index notations with their corresponding filter expressions (`?(expr)`) from the temporary array
      def restore_filter_expressions!(path, filter_expressions)
        path.gsub!(INDEX_NOTATION_REGEX) do
          filter_expressions[Regexp.last_match(1).to_i]
        end
      end

      def remove_root!(path)
        path.gsub!(/\A\$(;|\z)/, '') # Remove root operator
      end
    end
  end
end
