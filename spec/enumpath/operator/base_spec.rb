# frozen_string_literal: true

RSpec.describe Enumpath::Operator::Base do
  describe '#keys' do
    let(:instance) { Enumpath::Operator::Base.new('') }
    let(:subject) { instance.send(:keys, enum) }

    context 'when enum is an Array' do
      let(:enum) { %w(look mom i am an array) }

      it 'returns a set of indexes for the array' do
        expect(subject).to eq((0...enum.size).to_a)
      end
    end

    context 'when enum is a Hash' do
      let(:enum) { { name: 'Mom', age: 'imortal', power: '9001' } }

      it 'returns a set of keys from the hash' do
        expect(subject).to eq(enum.keys)
      end
    end

    context 'when enum is a Struct' do
      let(:struct) { Struct.new('Enumpath_Operator_Base_Test_Struct', :material, :price, :inventory) }
      let(:enum) { struct.new('plastic', 17.99) }

      it 'returns a list of attributes from the struct' do
        expect(subject).to eq(%i(material price inventory))
      end
    end

    context 'when enum is an object that responds to :to_h' do
      let(:object) do
        class Enumpath::Operator::Base::TestObject
          def to_h
            { a: :b, c: :d }
          end
        end
        Enumpath::Operator::Base::TestObject
      end
      let(:enum) { object.new }

      it 'returns the keys from the hash that #to_h returns' do
        expect(subject).to eq(%i(a c))
      end
    end

    context 'when enum is anything else' do
      let(:enum) { 'anything else' }

      it 'returns []' do
        expect(subject).to eq([])
      end
    end
  end
end
