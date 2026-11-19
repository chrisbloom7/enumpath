# frozen_string_literal: true

RSpec.describe Enumpath::Operator::Base do
  describe '#keys' do
    let(:instance) { Enumpath::Operator::Base.new('') }
    let(:subject) { instance.send(:keys, enum) }

    context 'when enum is an Array' do
      let(:enum) { %w[look mom i am an array] }

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
        expect(subject).to eq(%i[material price inventory])
      end
    end

    context 'when enum is an object that responds to :to_h' do
      let(:object) do
        class Enumpath::Operator::Base::TestObject # rubocop:disable Style/ClassAndModuleChildren
          def to_h
            { a: :b, c: :d }
          end
        end
        Enumpath::Operator::Base::TestObject
      end
      let(:enum) { object.new }

      it 'returns the keys from the hash that #to_h returns when the policy allows calling it' do
        Enumpath::Resolver::Property.with_policy(:all) { expect(subject).to eq(%i[a c]) }
        Enumpath::Resolver::Property.with_policy(:readers) { expect(instance.send(:keys, enum)).to eq(%i[a c]) }
      end

      it 'returns [] under the default :safe policy without calling #to_h' do
        expect(enum).not_to receive(:to_h)
        expect(subject).to eq([])
      end
    end

    context 'when enum is a Hash subclass that overrides #keys' do
      let(:enum) do
        Class.new(Hash) do
          def keys
            raise 'overridden keys should not be called'
          end
        end.new.merge!(a: 1)
      end

      it "uses Hash's own #keys" do
        expect(subject).to eq([:a])
      end
    end

    context 'when enum is an Enumerator' do
      let(:enum) { Enumerator.new { |yielder| raise 'the enumerator should not run' if yielder } }

      it 'returns [] without running it' do
        expect(subject).to eq([])
      end
    end

    if Enumpath::Resolver::Simple::DATA_CLASS
      context 'when enum is a Data object' do
        let(:enum) { Enumpath::Resolver::Simple::DATA_CLASS.define(:material, :price).new(material: 'wood', price: 2) }

        it 'returns its member names' do
          expect(subject).to eq(%i[material price])
        end
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
