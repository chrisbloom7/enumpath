# frozen_string_literal: true

RSpec.describe Enumpath::Resolver::Simple do
  describe '.resolve' do
    context 'numbers' do
      let(:enum) { { '1': 'symbol', '1' => 'string', 1 => 'number' } }

      it 'prefers numbers over strings' do
        expect(described_class.resolve('1', enum)).to eq('number')
      end

      it 'returns nil when a enumerable does not respond to the number' do
        expect(described_class.resolve('1', Object.new)).to be_nil
        expect(described_class.resolve('1', [])).to be_nil
        expect(described_class.resolve('1', {})).to be_nil
        expect(described_class.resolve('1', Struct.new('Enumpath_Resolver_Simple_Missing_Number_Test').new)).to be_nil
      end
    end

    context 'strings' do
      let(:enum) { { thing: 'symbol', 'thing' => 'string' } }

      it 'prefers strings over symbols' do
        expect(described_class.resolve('thing', enum)).to eq('string')
      end

      it 'returns nil when a enumerable does not respond to the string' do
        expect(described_class.resolve('thing', Object.new)).to be_nil
        expect(described_class.resolve('thing', [])).to be_nil
        expect(described_class.resolve('thing', {})).to be_nil
        expect(
          described_class.resolve('thing', Struct.new('Enumpath_Resolver_Simple_Missing_String_Test').new)
        ).to be_nil
      end
    end

    context 'symbols' do
      let(:enum) { { symbol: 'symbol' } }

      it 'prefers symbols lastly' do
        expect(described_class.resolve('symbol', enum)).to eq('symbol')
      end

      it 'returns nil when a enumerable does not respond to the symbol' do
        expect(described_class.resolve('symbol', Object.new)).to be_nil
        expect(described_class.resolve('symbol', [])).to be_nil
        expect(described_class.resolve('symbol', {})).to be_nil
        expect(
          described_class.resolve('symbol', Struct.new('Enumpath_Resolver_Simple_Missing_Symbol_Test').new)
        ).to be_nil
      end
    end
  end
end
