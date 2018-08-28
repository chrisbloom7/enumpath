# frozen_string_literal: true

require 'mini_cache'
require "enumpath/logger"
require "enumpath/operator"
require "enumpath/path"
require "enumpath/results"
require "enumpath/resolver/simple"
require "enumpath/resolver/property"
require "enumpath/version"

module Enumpath
  class << self
    attr_accessor :verbose

    @verbose = false

    def logger
      @logger ||= Enumpath::Logger.new
    end

    def log(title)
      block_given? ? logger.log(title, &Proc.new) : logger.log(title)
    end

    def path_cache
      @path_cache ||= MiniCache::Store.new
    end

    def apply(path, enum, options = {})
      logger.level = 0
      @verbose = options.delete(:verbose) || false
      Enumpath::Path.new(path, result_type: options.delete(:result_type)).apply(enum)
    end
  end
end
