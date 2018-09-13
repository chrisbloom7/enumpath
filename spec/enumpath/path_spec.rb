# frozen_string_literal: true

RSpec.describe Enumpath::Path do
  let(:path) { '$.workers' }
  let(:subject) { described_class.new(path) }
  let(:normalized_path) { Enumpath::Path::NormalizedPath.new(path) }

  describe '.new' do
    it 'automatically normalizes string paths' do
      expect(subject.path).to eq(normalized_path)
    end

    context 'path cache' do
      let(:uncached_path) { double('UncachedPath') }

      after { Enumpath.path_cache.reset }

      it 'fetchs normalized paths from the path cache if they exist' do
        Enumpath.path_cache.set(path, uncached_path)
        expect { subject.path }.not_to change { Enumpath.path_cache.get(path) }.from(uncached_path)
        expect(subject.path).to eq(uncached_path)
      end

      it 'adds normalized paths to the cache if they do not exist yet' do
        expect { subject.path }.to change { Enumpath.path_cache.get(path) }.from(nil).to(normalized_path)
      end
    end
  end

  describe '#apply' do
    let(:enum) { { workers: workers } }
    let(:workers) { %w[Barry Kari Larry Laurie] }

    it 'calls #trace with the normalized path and the enumerable' do
      expect(subject).to receive(:trace).with(normalized_path, enum)
      subject.apply(enum)
    end

    it 'returns a Enumpath::Results array' do
      expect(subject.apply(enum)).to be_a(Enumpath::Results)
    end

    it 'clears the results between calls' do
      subject.apply(enum)
      expect { subject.apply({}) }.to change { subject.results.empty? }.from(false).to(true)
    end
  end
end
