# frozen_string_literal: true

RSpec.describe Enumpath::Resolver::Property do
  describe '.resolve' do
    context 'properties' do
      let(:enum) do
        class Enumpath::Resolver::Property::ObjectWithProperty < Hash # rubocop:disable Style/ClassAndModuleChildren
          def public_property
            'public property'
          end

          def public_property_with_args(_required_arg)
            'public property with args'
          end

          private

          def private_property
            'private property'
          end
        end
        Enumpath::Resolver::Property::ObjectWithProperty.new
      end

      it 'resolves public properties with the :all policy' do
        expect(described_class.resolve('public_property', enum, :all)).to eq('public property')
      end

      it 'does not resolve custom methods on a core subclass with the default :safe policy' do
        expect(described_class.resolve('public_property', enum)).to be_nil
      end

      it 'returns nil when the property expects arguments' do
        expect(described_class.resolve('public_property_with_args', enum, :all)).to be_nil
        expect(described_class.resolve('public_property_with_args', enum)).to be_nil
      end

      it 'returns nil when a private property is called' do
        expect(described_class.resolve('private_property', enum, :all)).to be_nil
        expect(described_class.resolve('private_property', enum)).to be_nil
      end

      it 'returns nil when a enumerable does not respond to the property' do
        expect(described_class.resolve('missing_property', Object.new)).to be_nil
        expect(described_class.resolve('missing_property', [])).to be_nil
        expect(described_class.resolve('missing_property', {})).to be_nil
        expect(
          described_class.resolve(
            'missing_property', Struct.new('Enumpath_Resolver_Property_Missing_Property_Test').new
          )
        ).to be_nil
      end
    end

    context 'with the :safe policy' do
      let(:poro) do
        Class.new do
          attr_reader :name

          def initialize
            @name = 'widget'
            @secret = 'hidden'
          end

          def reset
            @name = nil
          end

          def length
            raise 'custom length should not be called'
          end

          private

          attr_reader :secret
        end.new
      end

      it 'resolves allowlisted read-only methods on core data' do
        expect(described_class.resolve('length', [1, 2], :safe)).to eq(2)
        expect(described_class.resolve('keys', { a: 1 }, :safe)).to eq([:a])
        expect(described_class.resolve('upcase', 'abc', :safe)).to eq('ABC')
        expect(described_class.resolve('even?', 2, :safe)).to be(true)
        expect(described_class.resolve('to_h', Struct.new(:a).new(1), :safe)).to eq(a: 1)
      end

      it 'does not resolve mutating methods on core data' do
        array = [3, 1, 2]
        %w[pop shift clear freeze sort! compact! delete_if].each do |name|
          expect(described_class.resolve(name, array, :safe)).to be_nil
        end
        expect(array).to eq([3, 1, 2])
        expect(array).not_to be_frozen
      end

      it 'does not resolve names that are not plain identifiers' do
        expect(described_class.resolve('upcase!', +'abc', :safe)).to be_nil
        expect(described_class.resolve('name=', poro, :safe)).to be_nil
        expect(described_class.resolve('Length', [1], :safe)).to be_nil
      end

      it 'resolves attr_readers on plain Ruby objects' do
        expect(described_class.resolve('name', poro, :safe)).to eq('widget')
      end

      it 'does not resolve other methods on plain Ruby objects' do
        expect(described_class.resolve('reset', poro, :safe)).to be_nil
        expect(poro.name).to eq('widget')
        expect(described_class.resolve('length', poro, :safe)).to be_nil
      end

      it 'does not resolve private readers' do
        expect(described_class.resolve('secret', poro, :safe)).to be_nil
      end

      it 'does not treat instance variables of modules as readers' do
        expect(described_class.resolve('logger', Enumpath, :safe)).to be_nil
      end

      it 'does not call allowlisted methods on objects that are not plain data' do
        expect(described_class.resolve('first', 1..Float::INFINITY, :safe)).to be_nil
        expect(described_class.resolve('first', [1, 2].each, :safe)).to be_nil
      end

      it 'returns nil instead of raising when a read-only method raises' do
        expect(described_class.resolve('sum', %w[a b], :safe)).to be_nil
        expect(described_class.resolve('floor', Float::INFINITY, :safe)).to be_nil
      end
    end

    context 'with the :none policy' do
      it 'never calls methods' do
        expect(described_class.resolve('length', [1, 2], :none)).to be_nil
      end
    end

    context 'with a callable policy' do
      it 'calls the method only when the callable returns a truthy value' do
        expect(described_class.resolve('length', [1, 2], ->(_object, name) { name == 'length' })).to eq(2)
        expect(described_class.resolve('length', [1, 2], ->(_object, _name) {})).to be_nil
      end
    end
  end

  describe '.current_policy' do
    it 'defaults to :safe' do
      expect(described_class.current_policy).to eq(:safe)
    end
  end

  describe '.with_policy' do
    it 'sets the current policy for the block and restores it afterwards' do
      described_class.with_policy(:none) do
        expect(described_class.current_policy).to eq(:none)
        described_class.with_policy(:all) { expect(described_class.current_policy).to eq(:all) }
        expect(described_class.current_policy).to eq(:none)
      end
      expect(described_class.current_policy).to eq(:safe)
    end

    it 'uses the default policy for nil' do
      described_class.with_policy(nil) { expect(described_class.current_policy).to eq(:safe) }
    end

    it 'raises ArgumentError for an invalid policy without changing the current policy' do
      described_class.with_policy(:none) do
        expect { described_class.with_policy(:readers) { nil } }.to raise_error(ArgumentError, /:readers/)
        expect(described_class.current_policy).to eq(:none)
      end
    end
  end
end
