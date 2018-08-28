# frozen_string_literal: true

RSpec.describe Enumpath::Resolver::Property do
  describe '.resolve' do
    context 'properties' do
      let(:enum) do
        class Enumpath::Resolver::Property::ObjectWithProperty < Hash
          def public_property
            'public property'
          end

          def public_property_with_args(required_arg)
            'public property with args'
          end

          private

          def private_property
            'private property'
          end
        end
        Enumpath::Resolver::Property::ObjectWithProperty.new
      end

      it 'resolves public properties' do
        expect(described_class.resolve('public_property', enum)).to eq('public property')
      end

      it 'returns nil when the property expects arguments' do
        expect(described_class.resolve('public_property_with_args', enum)).to be_nil
      end

      it 'returns nil when a private property is called' do
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
  end
end
