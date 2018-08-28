# frozen_string_literal: true

# Implements JSONPath child operator syntax. In a non-normalized path a child operator
# is preceded by `.` or wrapped in '[]'. In a normalized path the child operator is the
# segment that followed the `.` or that was contained within the '[]'. In bracket notation
# the child may optionally be wrapped in single quotes. If the child operator matches a
# index, key, member, or property of the enumerable, it is yielded to the block.

module Enumpath
  module Operator
    class Child < Base
      class << self
        def detect?(operator, enum)
          !Enumpath::Resolver::Simple.resolve(operator, enum).nil? ||
            !Enumpath::Resolver::Property.resolve(operator, enum).nil?
        end
      end

      def apply(remaining_segments, enum, current_path, &block)
        value = Enumpath::Resolver::Simple.resolve(operator, enum)
        value = Enumpath::Resolver::Property.resolve(operator, enum) if value.nil?
        yield(remaining_segments, value, current_path + [operator]) if !value.nil?
      end
    end
  end
end
