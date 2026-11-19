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

      context 'when a method shares its name with an instance variable' do
        let(:account) do
          Class.new do
            attr_reader :balance

            def initialize
              @balance = 100
              @withdraw = 50
            end

            def withdraw
              @balance -= @withdraw
            end
          end.new
        end

        it 'reads the instance variable instead of calling the method' do
          expect(described_class.resolve('withdraw', account, :safe)).to eq(50)
          expect(account.balance).to eq(100)
        end
      end

      it 'reads the instance variable when the method comes from method_missing' do
        object = Class.new do
          def initialize
            @name = 'stored'
          end

          def method_missing(name, *args)
            name == :name ? raise('method_missing should not be called') : super
          end

          def respond_to_missing?(name, include_private = false)
            name == :name || super
          end
        end.new
        expect(described_class.resolve('name', object, :safe)).to eq('stored')
      end

      it 'is not fooled by an object that overrides respond_to? or is_a?' do
        object = Class.new do
          def initialize
            @secret = 'hidden'
          end

          def respond_to?(*)
            true
          end

          def is_a?(*)
            false
          end
        end.new
        expect(described_class.resolve('secret', object, :safe)).to be_nil
        hash_lying_about_its_class = { a: 1 }.extend(Module.new { define_method(:is_a?) { |*| false } })
        expect(described_class.resolve('clear', hash_lying_about_its_class, :safe)).to be_nil
        expect(hash_lying_about_its_class).to eq(a: 1)
      end
    end

    context 'with the :readers policy' do
      let(:person) do
        Class.new do
          attr_reader :first_name, :last_name

          def initialize
            @first_name = 'Ada'
            @last_name = 'Lovelace'
            @saved = false
          end

          def full_name
            "#{first_name} #{last_name}"
          end

          def save
            @saved = true
          end

          def destroy
            raise 'destroy should not be called'
          end

          def saved?
            @saved
          end
        end.new
      end

      let(:model) do
        Class.new do
          def attributes
            { 'email' => 'ada@example.com', 'id' => 1 }
          end

          def respond_to_missing?(name, include_private = false)
            attributes.key?(name.to_s) || super
          end

          def method_missing(name, *args)
            attributes.key?(name.to_s) ? attributes[name.to_s] : super
          end

          def reload
            raise 'reload should not be called'
          end
        end.new
      end

      it 'resolves computed readers on plain objects' do
        expect(described_class.resolve('full_name', person, :readers)).to eq('Ada Lovelace')
        expect(described_class.resolve('full_name', person, :safe)).to be_nil
      end

      it 'resolves ActiveModel-style attributes' do
        expect(described_class.resolve('email', model, :readers)).to eq('ada@example.com')
        attributes_only = Class.new do
          def attributes
            { 'email' => 'ada@example.com' }
          end
        end.new
        expect(described_class.resolve('email', attributes_only, :readers)).to eq('ada@example.com')
      end

      it 'does not call denylisted persistence methods' do
        %w[save destroy].each { |name| expect(described_class.resolve(name, person, :readers)).to be_nil }
        expect(described_class.resolve('reload', model, :readers)).to be_nil
        expect(person.saved?).to be(false)
      end

      it 'does not call methods that Ruby itself defines on plain objects' do
        expect(described_class.resolve('freeze', person, :readers)).to be_nil
        expect(person).not_to be_frozen
      end

      it 'treats core objects exactly like :safe' do
        array = [3, 1, 2]
        %w[pop shift clear sort freeze].each { |name| described_class.resolve(name, array, :readers) }
        expect(array).to eq([3, 1, 2])
        expect(array).not_to be_frozen
        expect(described_class.resolve('length', array, :readers)).to eq(3)
        hash_subclass = Class.new(Hash) do
          def custom
            'custom'
          end
        end.new
        expect(described_class.resolve('custom', hash_subclass, :readers)).to be_nil
      end

      it 'does not resolve names that are not plain identifiers' do
        expect(described_class.resolve('first_name=', person, :readers)).to be_nil
      end

      it 'can be composed in a callable with .reader?' do
        expect(described_class.reader?(person, 'full_name')).to be(true)
        expect(described_class.reader?(person, 'save')).to be(false)
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
        expect { described_class.with_policy(:bogus) { nil } }.to raise_error(ArgumentError, /:bogus/)
        expect(described_class.current_policy).to eq(:none)
      end
    end
  end
end
