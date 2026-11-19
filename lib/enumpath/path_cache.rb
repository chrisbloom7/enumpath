# frozen_string_literal: true

module Enumpath
  # A small cache of normalized path expressions. It is guarded by a mutex, so threads can share it, and it holds at
  # most `max_size` entries: when it is full the least recently used entry is dropped, so a long-running process that
  # applies many distinct dynamic paths does not grow without limit.
  class PathCache
    # The number of entries kept when no size is given
    DEFAULT_MAX_SIZE = 1_000

    # @return [Integer] the most entries the cache keeps
    attr_reader :max_size

    # @param max_size [Integer] the most entries to keep
    # @raise [ArgumentError] if max_size is not a positive integer
    def initialize(max_size = DEFAULT_MAX_SIZE)
      raise ArgumentError, "max_size must be a positive Integer, got #{max_size.inspect}" unless valid_size?(max_size)

      @max_size = max_size
      @data = {}
      @mutex = Mutex.new
    end

    # @param key [#to_s] the key to look up
    # @return the cached value, or nil if there is none. A hit counts as a use.
    def get(key)
      key = key.to_s
      @mutex.synchronize { touch(key) ? @data[key] : nil }
    end

    # @param key [#to_s] the key to store the value under
    # @param value the value to store
    # @return the value
    def set(key, value)
      key = key.to_s
      @mutex.synchronize { store(key, value) }
    end

    # Returns the cached value for the key. When there is none, calls the block with the key, stores its result and
    # returns that. Two threads that miss at the same time may both call the block; the last result is kept.
    #
    # @param key [#to_s] the key to look up
    # @yieldparam key [String] the key as a string
    # @return the cached or computed value
    def get_or_set(key)
      key = key.to_s
      hit, value = @mutex.synchronize { touch(key) ? [true, @data[key]] : [false, nil] }
      return value if hit

      @mutex.synchronize { store(key, yield(key)) }
    end

    # Removes every entry
    #
    # @return [void]
    def reset
      @mutex.synchronize { @data.clear }
      nil
    end

    # @return [Integer] the number of entries
    def size
      @mutex.synchronize { @data.size }
    end

    private

    def valid_size?(max_size)
      max_size.is_a?(Integer) && max_size.positive?
    end

    # Moves an entry to the most recently used end. Call with the mutex held.
    def touch(key)
      return false unless @data.key?(key)

      @data[key] = @data.delete(key)
      true
    end

    # Call with the mutex held.
    def store(key, value)
      @data.delete(key)
      @data[key] = value
      @data.shift while @data.size > @max_size
      value
    end
  end
end
