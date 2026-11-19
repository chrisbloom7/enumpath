# frozen_string_literal: true

RSpec.describe Enumpath::PathCache do
  subject(:cache) { described_class.new(3) }

  describe '.new' do
    it 'defaults to a bounded size' do
      expect(described_class.new.max_size).to eq(described_class::DEFAULT_MAX_SIZE)
    end

    [0, -1, 1.5, '3', nil].each do |bad|
      it "raises an ArgumentError for a max size of #{bad.inspect}" do
        expect { described_class.new(bad) }.to raise_error(ArgumentError, /max_size/)
      end
    end
  end

  describe '#get and #set' do
    it 'returns nil for a missing key' do
      expect(cache.get('a')).to be_nil
    end

    it 'stores and returns a value, and #set returns the value' do
      expect(cache.set('a', 1)).to eq(1)
      expect(cache.get('a')).to eq(1)
    end

    it 'treats keys as strings' do
      cache.set(:a, 1)
      expect(cache.get('a')).to eq(1)
    end

    it 'replaces the value of an existing key without growing' do
      cache.set('a', 1)
      cache.set('a', 2)
      expect([cache.get('a'), cache.size]).to eq([2, 1])
    end
  end

  describe '#get_or_set' do
    it 'computes, stores and returns the block value for a missing key' do
      expect(cache.get_or_set('a') { 1 }).to eq(1)
      expect(cache.get('a')).to eq(1)
    end

    it 'does not call the block for a key that is cached' do
      cache.set('a', 1)
      expect { |block| cache.get_or_set('a', &block) }.not_to yield_control
      expect(cache.get_or_set('a') { 2 }).to eq(1)
    end

    it 'caches a falsy value' do
      cache.get_or_set('a') { false }
      expect(cache.get_or_set('a') { true }).to be(false)
    end
  end

  describe 'the size bound' do
    before { %w[a b c].each { |key| cache.set(key, key) } }

    it 'drops the least recently used entry when full' do
      cache.set('d', 'd')
      expect([cache.get('a'), cache.get('b'), cache.get('c'), cache.get('d')]).to eq([nil, 'b', 'c', 'd'])
    end

    it 'counts a read as a use' do
      cache.get('a')
      cache.set('d', 'd')
      expect([cache.get('a'), cache.get('b')]).to eq(%w[a] + [nil])
    end

    it 'never holds more than max_size entries' do
      20.times { |i| cache.set("key#{i}", i) }
      expect(cache.size).to eq(3)
    end
  end

  describe '#reset' do
    it 'empties the cache' do
      cache.set('a', 1)
      cache.reset
      expect([cache.get('a'), cache.size]).to eq([nil, 0])
    end
  end

  describe 'from several threads' do
    it 'stays consistent and within its bound' do
      shared = described_class.new(50)
      threads = Array.new(8) do |t|
        Thread.new { 500.times { |i| shared.get_or_set("path#{(i * (t + 1)) % 120}", &:upcase) } }
      end
      threads.each(&:join)
      expect(shared.size).to be <= 50
      expect(shared.get_or_set('path1') { 'new' }).to eq('PATH1').or eq('new')
    end
  end
end
