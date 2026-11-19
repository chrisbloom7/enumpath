# frozen_string_literal: true

# A performance baseline for Enumpath: times a fixed set of paths against fixed data so a change can be compared with
# the numbers recorded before it. It uses only the standard library and runs on Ruby 2.6 and up.
#
#   ruby benchmarks/baseline.rb                           # print a table
#   ruby benchmarks/baseline.rb --json out.json           # also write the results as JSON
#   ruby benchmarks/baseline.rb --compare benchmarks/baseline-0.2.1.json
#   ruby benchmarks/baseline.rb --only wildcard           # only scenarios whose name matches
#   ruby benchmarks/baseline.rb --rounds 9 --batch 0.2    # more samples, longer batches
#
# Absolute times depend on the machine, so the table also shows each scenario as a multiple of a native `Hash#dig`
# call (the "x dig" column). Compare runs made on the same machine and Ruby; use the ratio to sanity-check across
# machines. Run it on an otherwise idle machine, and run it twice before trusting a small difference.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'benchmark'
require 'json'
require 'optparse'
require 'time'
require 'enumpath'

# Builds the data the scenarios run against
module BaselineData
  module_function

  def book(index)
    { category: %w[reference fiction].fetch(index % 2), author: "Author #{index}", title: "Title #{index}",
      isbn: "0-#{index}", price: ((index * 37) % 2500) / 100.0 }
  end

  # The "store" example from the JSONPath specification, with `count` books
  def store(count)
    { store: { book: Array.new(count) { |i| book(i) }, bicycle: { color: 'red', price: 19.95 } } }
  end

  # A deep, mostly hash-only structure, like an HR or payroll API response
  def worker
    { 'Worker_Data' => {
      'Personal_Data' => { 'Contact_Data' => { 'Address_Data' => [{ 'Address_Line_Data' => ['800 Alta Vista'] }] } },
      'Employment_Data' => { 'Worker_Job_Data' => [{ 'Position_Data' => { 'Position_Title' => 'Sr. Engineer' } }] }
    } }
  end
end

SMALL_STORE = BaselineData.store(4)
LARGE_STORE = BaselineData.store(10_000)
WORKER = BaselineData.worker
WORKER_KEYS = ['Worker_Data', 'Employment_Data', 'Worker_Job_Data', 0, 'Position_Data', 'Position_Title'].freeze
WORKER_PATH = 'Worker_Data.Employment_Data.Worker_Job_Data.0.Position_Data.Position_Title'

# name, path, data, and what a correct run returns (a count of matches, checked once so a broken path cannot pass
# for a fast one)
SCENARIOS = [
  # Plain keys and indexes (the case #3 and #51 are about)
  ['child_short',       '$.store.bicycle.color',                   SMALL_STORE, 1],
  ['child_deep',        WORKER_PATH,                               WORKER,      1],
  ['index',             '$.store.book[0].title',                   SMALL_STORE, 1],
  ['bracket_notation',  "$['store']['book'][0]['title']",          SMALL_STORE, 1],
  # Operators on a small document: per-call overhead
  ['wildcard_small',    '$.store.book[*].author',                  SMALL_STORE, 4],
  ['recursive_small',   '$..author',                               SMALL_STORE, 4],
  ['slice_small',       '$.store.book[1:3].title',                 SMALL_STORE, 2],
  ['union_small',       '$.store.book[0,2].title',                 SMALL_STORE, 2],
  ['subscript_small',   '$.store.book[(@.length-1)].title',        SMALL_STORE, 1],
  ['filter_small',      '$..book[?(@.price<10)].title',            SMALL_STORE, nil],
  ['filter_regex_small', '$.store.book[?(@.author =~ /author 1/i)]', SMALL_STORE, 1],
  # The same operators on 10,000 books: per-element cost
  ['wildcard_large',    '$.store.book[*].author',                  LARGE_STORE, 10_000],
  ['recursive_large',   '$..price',                                LARGE_STORE, 10_001],
  ['filter_large',      '$..book[?(@.price<10)]',                  LARGE_STORE, nil],
  ['slice_large',       '$.store.book[0:9999:3].author',           LARGE_STORE, nil]
].freeze

# Runs a block enough times per batch to take about `batch` seconds, then times `rounds` batches
class Timer
  def initialize(rounds:, batch:)
    @rounds = rounds
    @batch = batch
  end

  # @return [Hash{Symbol => Float}] microseconds per call
  def measure(&block)
    GC.start
    block.call
    iterations = calibrate(&block)
    samples = Array.new(@rounds) { time_batch(iterations, &block) / iterations }.sort
    { median_us: samples[samples.size / 2] * 1e6, min_us: samples.first * 1e6, iterations: iterations }
  end

  private

  def calibrate(&block)
    iterations = 1
    iterations *= 2 while time_batch(iterations, &block) < @batch / 4.0 && iterations < 1 << 24
    iterations
  end

  def time_batch(iterations, &block)
    Benchmark.realtime { iterations.times(&block) }
  end
end

# Runs the scenarios and returns the results keyed by scenario name
class Runner
  def initialize(options)
    @only = options[:only] && Regexp.new(options[:only])
    @timer = Timer.new(rounds: options[:rounds], batch: options[:batch])
  end

  def run
    dig = @timer.measure { WORKER.dig(*WORKER_KEYS) }
    results = {}
    SCENARIOS.each do |name, path, data, expected|
      next if @only && name !~ @only

      results[name] = run_scenario(name, path, data, expected, dig)
      warn format('  %<name>-20s %<us>12.2f us', name: name, us: results[name][:median_us])
    end
    results['native_dig'] = dig.merge(matches: 1, times_dig: 1.0)
    results
  end

  private

  def run_scenario(name, path, data, expected, dig)
    matches = Enumpath.apply(path, data).size
    raise "#{name}: expected #{expected} matches, got #{matches}" if expected && matches != expected
    raise "#{name}: no matches" if matches.zero?

    result = @timer.measure { Enumpath.apply(path, data) }
    result.merge(matches: matches, times_dig: result[:median_us] / dig[:median_us])
  end
end

# Prints the results as a table, with the change from an earlier run when there is one
class Report
  def initialize(results, previous)
    @results = results
    @previous = previous
  end

  def self.time(microseconds)
    return format('%<n>.2f us', n: microseconds) if microseconds < 1000
    return format('%<n>.2f ms', n: microseconds / 1000) if microseconds < 1_000_000

    format('%<n>.2f s', n: microseconds / 1_000_000)
  end

  def print
    header = format('%<a>-20s %<b>8s %<c>12s %<d>9s', a: 'scenario', b: 'matches', c: 'median', d: 'x dig')
    header += format(' %<a>12s %<b>9s', a: 'before', b: 'change') if @previous
    puts header, '-' * header.size
    @results.each { |name, result| puts row(name, result) }
    puts "\nbefore: #{label}" if @previous
  end

  private

  def row(name, result)
    line = format('%<name>-20s %<matches>8d %<median>12s %<times>9.0f',
                  name: name, matches: result[:matches], median: self.class.time(result[:median_us]),
                  times: result[:times_dig])
    old = @previous && @previous[:results][name.to_sym]
    old ? line + change(result, old) : line
  end

  def change(result, old)
    percent = (result[:median_us] / old[:median_us] - 1) * 100
    format(' %<before>12s %<change>+8.1f%%', before: self.class.time(old[:median_us]), change: percent)
  end

  def label
    meta = @previous[:meta]
    "#{meta[:enumpath]} (#{meta[:git_sha]}), #{meta[:ruby]}"
  end
end

def metadata
  sha = `git -C #{__dir__} rev-parse --short HEAD 2>/dev/null`.strip
  { ruby: RUBY_DESCRIPTION, platform: RUBY_PLATFORM, enumpath: Enumpath::VERSION, git_sha: sha,
    recorded_at: Time.now.utc.iso8601 }
end

def parse_options
  options = { rounds: 7, batch: 0.15 }
  parser = OptionParser.new('Usage: ruby benchmarks/baseline.rb [options]')
  parser.on('--json FILE', 'write the results to FILE as JSON') { |file| options[:json] = file }
  parser.on('--compare FILE', 'compare with results written by --json') { |file| options[:compare] = file }
  parser.on('--only REGEX', 'run only scenarios whose name matches') { |regex| options[:only] = regex }
  parser.on('--rounds N', Integer, 'timed batches per scenario (default 7)') { |rounds| options[:rounds] = rounds }
  parser.on('--batch SECONDS', Float, 'target length of a batch (default 0.15)') { |batch| options[:batch] = batch }
  parser.parse!
  options
end

options = parse_options
previous = JSON.parse(File.read(options[:compare]), symbolize_names: true) if options[:compare]
warn "Ruby #{RUBY_VERSION}, Enumpath #{Enumpath::VERSION}"
results = Runner.new(options).run
puts
Report.new(results, previous).print
File.write(options[:json], "#{JSON.pretty_generate(meta: metadata, results: results)}\n") if options[:json]
