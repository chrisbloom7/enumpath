# frozen_string_literal: true

require 'stringio'

RSpec.describe 'Thread safety' do
  # Runs the block with Enumpath's logger writing to a StringIO, then restores it
  def capturing_log
    io = StringIO.new
    original = Enumpath.logger.logger
    Enumpath.logger.logger = ::Logger.new(io)
    yield io
  ensure
    Enumpath.logger.logger = original
  end

  # A property resolver policy that parks the calling thread until `resume` has a value, after telling `parked`
  def parking_policy(parked, resume)
    lambda do |_object, _name|
      parked << true
      resume.pop
      false
    end
  end

  # Holds thread A inside an Enumpath.apply call, runs the block in another thread while A is parked, then lets A
  # finish. Returns what the block returned.
  def while_parked(a_options)
    parked = Queue.new
    resume = Queue.new
    policy = parking_policy(parked, resume)
    thread = Thread.new { Enumpath.apply('missing', Object.new, a_options.merge(property_resolver: policy)) }
    parked.pop
    yield
  ensure
    resume << true
    thread&.join
  end

  describe 'verbose mode' do
    it 'is off when a call in another thread has verbose: true' do
      seen = while_parked(verbose: true) { Thread.new { Enumpath.verbose }.value }
      expect(seen).to be(false)
    end

    it 'applies to the call that asked for it, and is restored afterwards' do
      capturing_log do |io|
        Enumpath.apply('a', { a: 1 }, verbose: true)
        expect(io.string).to include('Enumpath: Applying')
        expect(Enumpath.verbose).to be(false)
      end
    end

    it 'lets verbose: false switch off a global Enumpath.verbose = true for one call' do
      capturing_log do |io|
        Enumpath.verbose = true
        Enumpath.apply('a', { a: 1 }, verbose: false)
        expect(io.string).to be_empty
      end
    end

    it 'uses Enumpath.verbose as the default for calls that do not pass the option' do
      capturing_log do |io|
        Enumpath.verbose = true
        Enumpath.apply('a', { a: 1 })
        expect(io.string).to include('Enumpath: Applying')
      end
    end

    it 'restores the previous setting when the call raises' do
      expect { Enumpath.apply('a', {}, verbose: true, property_resolver: :bogus) }.to raise_error(ArgumentError)
      expect(Enumpath.verbose).to be(false)
    end
  end

  describe 'the logger indentation level' do
    it 'is not shared between threads' do
      level_elsewhere = while_parked({}) do
        Enumpath.logger.level = 3
        Thread.new { Enumpath.logger.level }.value
      end
      expect(level_elsewhere).to eq(0)
    end
  end

  describe 'log messages' do
    # A log device that records each write, and is slow enough for other threads to run in between
    let(:sink) do
      Class.new do
        attr_reader :writes

        def initialize
          @writes = Queue.new
        end

        def <<(message)
          sleep 0.0002
          @writes << message
        end
      end.new
    end

    it 'are written whole, so threads cannot interleave the lines of one message' do
      original = Enumpath.logger.logger
      Enumpath.logger.logger = sink
      Array.new(4) { Thread.new { 10.times { Enumpath.apply('a.b', { a: { b: 1 } }, verbose: true) } } }.each(&:join)
      writes = Array.new(sink.writes.size) { sink.writes.pop }
      expect(writes).not_to be_empty
      expect(writes).to all(match(/\A\s*-{10,}\n\s*Enumpath: .+\n/))
    ensure
      Enumpath.logger.logger = original
    end
  end

  describe 'shared objects' do
    it 'are the same object in every thread, from the first use' do
      objects = Array.new(8) { Thread.new { [Enumpath.logger, Enumpath.path_cache] } }.map(&:value)
      expect(objects.map(&:first).uniq.size).to eq(1)
      expect(objects.map(&:last).uniq.size).to eq(1)
    end
  end

  describe 'many calls at once' do
    let(:store) { { a: [{ n: 1, s: 'x' }, { n: 2, s: 'y' }], b: { c: 3 } } }

    it 'give each call its own results, whatever options the other threads use' do
      cases = [
        ['a[*].n', {}, [1, 2]],
        ['a[1].s', {}, ['y']],
        ['b.c', { result_type: :path }, ["$['b']['c']"]],
        ['a[?(@.n > 1)].s', {}, ['y']],
        ['a[?(@.s =~ /^x/)].n', { regexp_timeout: 0.5 }, [1]],
        ['a.length', { property_resolver: :none }, []],
        ['a.length', { property_resolver: :safe }, [2]],
        ['$..c', { verbose: false }, [3]]
      ]
      failures = Queue.new
      threads = Array.new(8) do |t|
        Thread.new do
          200.times do |i|
            path, options, expected = cases[(i + t) % cases.size]
            actual = Enumpath.apply(path, store, options)
            failures << [path, options, actual] unless actual == expected
          end
        end
      end
      threads.each(&:join)
      expect(failures.size).to eq(0), "wrong results: #{Array.new(failures.size) { failures.pop }.first(3).inspect}"
    end

    it 'keeps a regular expression timeout to the call that hit it' do
      skip 'needs Ruby 3.2 or later' unless Enumpath::RegexpTimeout::SUPPORTED

      hostile = [{ s: "#{'a' * 28}!" }]
      normal = Thread.new { 200.times.map { Enumpath.apply('[?(@.s =~ /^o/)]', [{ s: 'ok' }]).size } }
      expect(Enumpath.apply('[?(@.s =~ /^(a*)*\\1$/)]', hostile, regexp_timeout: 0.05)).to eq([])
      expect(normal.value.uniq).to eq([1])
    end
  end
end
