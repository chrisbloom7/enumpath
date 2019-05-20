# frozen_string_literal: true

RSpec.describe Enumpath::Path::Normalized do
  let(:subject) { described_class.new('') }

  it 'is a subclass of Array' do
    expect(subject).to be_a_kind_of(Array)
  end

  describe '.new' do
    describe 'path normalizion' do
      it 'removes the root operator when present' do
        expect(described_class.new('$')).to eq([])
        expect(described_class.new('$.cat')).to eq(['cat'])
        expect(described_class.new('$..cat')).to eq(['..', 'cat'])
      end

      it 'normalizes the path even without the root operator' do
        expect(described_class.new('..cat')).to eq(['..', 'cat'])
      end

      it 'normalizes wildcard operators' do
        expect(described_class.new('a.*.b[*]')).to eq(%w[a * b *])
      end

      it 'normalizes recursive descent operators' do
        expect(described_class.new('a..c')).to eq(%w[a .. c])
      end

      it 'normalizes child dot operators' do
        expect(described_class.new('a.b.c')).to eq(%w[a b c])
      end

      it 'normalizes child bracket operators' do
        expect(described_class.new('$[a][\'b\']["c"]')).to eq(['a', 'b', '"c"'])
      end

      it 'normalizes union operators' do
        expect(described_class.new('$[a,b]')).to eq(['a,b'])
        expect(described_class.new('$[a,b,c]')).to eq(['a,b,c'])
        expect(described_class.new('$[\'a\',\'b\',\'c\']')).to eq(['a\',\'b\',\'c'])
      end

      it 'normalizes slice operators' do
        expect(described_class.new('$[1:2:3]')).to eq(['1:2:3'])
        expect(described_class.new('$[1:2]')).to eq(['1:2'])
        expect(described_class.new('$[1:]')).to eq(['1:'])
        expect(described_class.new('$[:2:3]')).to eq([':2:3'])
        expect(described_class.new('$[:2]')).to eq([':2'])
        expect(described_class.new('$[::3]')).to eq(['::3'])
      end

      it 'normalizes filter expression operators' do
        expect(described_class.new('$[?(@.author)]')).to eq(['?(@.author)'])
        expect(described_class.new('$[?()]')).to eq(['?()'])
      end

      it 'normalizes subscript expression operators' do
        expect(described_class.new('$[(@.length-1)]')).to eq(['(@.length-1)'])
        expect(described_class.new('$[()]')).to eq(['()'])
      end

      context 'when the path is already an array' do
        let(:vanilla_array) { %w[i am an array] }
        let(:normalized_path) { Enumpath::Path::Normalized.new('i.am.a.path') }

        it 'keeps the array as-is' do
          expect(described_class.new(vanilla_array)).to eq(vanilla_array)
          expect(described_class.new(normalized_path)).to eq(normalized_path)
        end
      end
    end
  end
end
