# frozen_string_literal: true

require 'timeout'

RSpec.describe 'Property resolution policies' do
  let(:poro_class) do
    Class.new do
      attr_reader :name, :owners, :destroyed

      def initialize(name, owners = [])
        @name = name
        @owners = owners
        @destroyed = false
      end

      def destroy
        @destroyed = true
        :destroyed
      end

      def label
        "label for #{name}"
      end
    end
  end

  describe 'the default (:safe) policy' do
    it 'does not clear a hash' do
      hash = { a: 1 }
      expect(Enumpath.apply('clear', hash)).to eq([])
      expect(hash).to eq(a: 1)
    end

    it 'does not pop an array' do
      array = [1, 2, 3]
      expect(Enumpath.apply('pop', array)).to eq([])
      expect(array).to eq([1, 2, 3])
    end

    it 'does not shift an array' do
      array = [1, 2, 3]
      expect(Enumpath.apply('shift', array)).to eq([])
      expect(array).to eq([1, 2, 3])
    end

    it 'does not sort an array in place' do
      array = [3, 1, 2]
      expect(Enumpath.apply('sort!', array)).to eq([])
      expect(array).to eq([3, 1, 2])
    end

    it 'does not freeze the target' do
      array = [1, 2, 3]
      expect(Enumpath.apply('freeze', array)).to eq([])
      expect(array).not_to be_frozen
    end

    it 'does not call a destructive custom method on a plain Ruby object' do
      object = poro_class.new('widget')
      expect(Enumpath.apply('destroy', object)).to eq([])
      expect(object.destroyed).to be(false)
    end

    it 'does not call an allowlisted name that a core subclass overrides' do
      counter = Class.new(Array) do
        attr_reader :calls

        def length
          @calls = (@calls || 0) + 1
        end
      end.new([1, 2])
      expect(Enumpath.apply('length', counter)).to eq([])
      expect(counter.calls).to be_nil
    end

    it 'resolves the README child operator example' do
      car = Struct.new(:color, :transmission, :owners)
      jeep = car.new('black', :automatic, [])
      subaru = car.new('gold', :standard, [{ name: 'Kate' }])
      garages = [{ 'cars' => [subaru] }, { 'cars' => [jeep] }]
      expect(Enumpath.apply('1.cars.0.owners.length', garages)).to eq([0])
      expect(Enumpath.apply('0.cars.0.color', garages)).to eq(['gold'])
    end

    it 'resolves subscript expressions that use length' do
      array = %w[a b c d e]
      expect(Enumpath.apply('[(@.length - 1)]', array)).to eq(['e'])
      expect(Enumpath.apply('[(length / 2)]', array)).to eq(['c'])
    end

    it 'resolves filter expressions that use length' do
      lists = { short: [1], long: [1, 2, 3] }
      expect(Enumpath.apply('[?(@.length > 2)]', lists)).to eq([[1, 2, 3]])
    end

    it 'traverses attr_readers on plain Ruby objects' do
      object = poro_class.new('widget', [{ name: 'Kate' }])
      expect(Enumpath.apply('name', object)).to eq(['widget'])
      expect(Enumpath.apply('owners.0.name', object)).to eq(['Kate'])
      expect(Enumpath.apply('owners.length', object)).to eq([1])
    end

    it 'does not run a method that shares its name with an instance variable' do
      account = Class.new do
        attr_reader :balance

        def initialize
          @balance = 100
          @withdraw = 50
        end

        def withdraw
          @balance -= @withdraw
        end
      end.new
      expect(Enumpath.apply('withdraw', account)).to eq([50])
      expect(Enumpath.apply('[?(@.withdraw)]', [account])).to eq([account])
      expect(account.balance).to eq(100)
    end

    it 'does not mutate data through filter or subscript expressions' do
      arrays = [[1, 2], [3]]
      expect(Enumpath.apply('[?(@.pop)]', arrays)).to eq([])
      expect(Enumpath.apply('[?(@.pop == 2)]', arrays)).to eq([])
      expect(arrays).to eq([[1, 2], [3]])
      hash = { a: 1 }
      expect(Enumpath.apply('[(@.clear)]', hash)).to eq([])
      expect(Enumpath.apply('[(clear)]', [hash])).to eq([])
      expect(hash).to eq(a: 1)
    end

    context 'when iterating over objects with a custom to_h' do
      let(:calls) { [] }
      let(:object) do
        log = calls
        Class.new do
          define_method(:to_h) do
            log << :to_h
            { a: 1 }
          end
        end.new
      end

      it 'does not call it for wildcards, filters or recursive descent' do
        expect(Enumpath.apply('*', object)).to eq([])
        expect(Enumpath.apply('[?(@)]', object)).to eq([])
        expect(Enumpath.apply('..a', { x: object })).to eq([])
        expect(calls).to be_empty
      end

      it 'calls it under :all as before' do
        Enumpath.apply('*', object, property_resolver: :all)
        expect(calls).to eq([:to_h])
      end
    end

    it 'does not consume an Enumerator when iterating over it' do
      consumed = []
      enumerator = Enumerator.new do |yielder|
        consumed << 1
        yielder << [:a, 1]
      end
      expect(Enumpath.apply('*', enumerator)).to eq([])
      expect(Enumpath.apply('[?(@)]', enumerator)).to eq([])
      expect(Enumpath.apply('..a', [enumerator])).to eq([])
      expect(consumed).to be_empty
    end

    if Enumpath::Resolver::Simple::DATA_CLASS
      it 'resolves and iterates Data members like Struct members' do
        point = Enumpath::Resolver::Simple::DATA_CLASS.define(:x, :y).new(x: 1, y: 2)
        expect(Enumpath.apply('x', point)).to eq([1])
        expect(Enumpath.apply('*', point)).to eq([1, 2])
        expect(Enumpath.apply('x', point, property_resolver: :none)).to eq([1])
      end
    end
  end

  describe 'property_resolver: :readers' do
    let(:model_class) do
      Class.new do
        attr_reader :saved

        def initialize(attributes)
          @attributes = attributes
          @saved = false
        end

        def attributes
          @attributes.dup
        end

        def display_name
          "#{attributes['name']} <#{attributes['email']}>"
        end

        def save
          @saved = true
        end

        def destroy
          raise 'destroy should not be called'
        end
      end
    end
    let(:users) { [model_class.new('name' => 'Ada', 'email' => 'ada@example.com')] }

    it 'resolves computed readers and attributes' do
      expect(Enumpath.apply('*.display_name', users, property_resolver: :readers)).to eq(['Ada <ada@example.com>'])
      expect(Enumpath.apply('0.email', users, property_resolver: :readers)).to eq(['ada@example.com'])
      expect(Enumpath.apply('[?(@.email =~ /example/)].display_name', users, property_resolver: :readers))
        .to eq(['Ada <ada@example.com>'])
    end

    it 'does not call persistence verbs' do
      expect(Enumpath.apply('0.save', users, property_resolver: :readers)).to eq([])
      expect(Enumpath.apply('0.destroy', users, property_resolver: :readers)).to eq([])
      expect(users.first.saved).to be(false)
    end

    it 'does not call core mutators' do
      array = [3, 1, 2]
      %w[pop shift clear sort! freeze].each { |name| Enumpath.apply(name, array, property_resolver: :readers) }
      expect(array).to eq([3, 1, 2])
      expect(array).not_to be_frozen
    end
  end

  describe 'property_resolver: :all' do
    it 'restores the previous unrestricted behavior' do
      hash = { a: 1 }
      expect(Enumpath.apply('clear', hash, property_resolver: :all)).to eq([{}])
      expect(hash).to eq({})
    end
  end

  describe 'property_resolver: :none' do
    it 'never calls methods, even allowlisted ones' do
      expect(Enumpath.apply('length', [1, 2, 3], property_resolver: :none)).to eq([])
    end

    it 'still resolves keys, indexes and Struct members' do
      struct = Struct.new(:color).new('red')
      expect(Enumpath.apply('color', struct, property_resolver: :none)).to eq(['red'])
      expect(Enumpath.apply('a.0', { a: [1] }, property_resolver: :none)).to eq([1])
    end
  end

  describe 'a callable property_resolver' do
    it 'calls the method only when the callable returns true' do
      policy = ->(_object, name) { name == 'label' }
      object = poro_class.new('widget')
      expect(Enumpath.apply('label', object)).to eq([])
      expect(Enumpath.apply('label', object, property_resolver: policy)).to eq(['label for widget'])
      expect(Enumpath.apply('length', [1], property_resolver: policy)).to eq([])
    end

    it 'can build on the :safe checks' do
      policy = ->(object, name) { Enumpath::Resolver::Property.safe?(object, name) || name == 'label' }
      objects = [poro_class.new('widget')]
      expect(Enumpath.apply('length', objects, property_resolver: policy)).to eq([1])
      expect(Enumpath.apply('0.label', objects, property_resolver: policy)).to eq(['label for widget'])
      expect(Enumpath.apply('0.destroy', objects, property_resolver: policy)).to eq([])
    end

    it 'skips the identifier and arity checks' do
      policy = ->(_object, _name) { true }
      expect(Enumpath.apply('[?(@.zero?)]', [0, 1], property_resolver: policy)).to eq([0])
      expect(Enumpath.apply('sort!', [3, 1, 2], property_resolver: policy)).to eq([[1, 2, 3]])
    end

    it 'receives the object and the property name as a String' do
      received = []
      policy = lambda do |object, name|
        received << [object, name]
        false
      end
      Enumpath.apply('length', [1], property_resolver: policy)
      expect(received.uniq).to eq([[[1], 'length']])
    end
  end

  describe 'invalid property_resolver values' do
    it 'raises ArgumentError' do
      expect { Enumpath.apply('length', [], property_resolver: :bogus) }
        .to raise_error(ArgumentError, /property_resolver/)
      expect { Enumpath.apply('length', [], property_resolver: 'all') }.to raise_error(ArgumentError)
    end
  end

  describe 'policy scoping' do
    it 'restores the previous policy after an exception' do
      policy = ->(_object, _name) { raise 'boom' }
      expect { Enumpath.apply('length', [1], property_resolver: policy) }.to raise_error('boom')
      expect(Enumpath::Resolver::Property.current_policy).to eq(:safe)
      expect(Enumpath.apply('length', [1])).to eq([1])
    end

    it 'restores the outer policy after a nested call' do
      inner_results = nil
      policy = lambda do |object, name|
        inner_results ||= Enumpath.apply('label', object)
        name == 'label'
      end
      object = poro_class.new('widget')
      expect(Enumpath.apply('label', object, property_resolver: policy)).to eq(['label for widget'])
      expect(inner_results).to eq([])
    end

    it 'applies the default to chained Results#apply calls unless the option is passed again' do
      results = Enumpath.apply('a', { a: poro_class.new('widget') }, property_resolver: :all)
      expect(results.apply('0.label')).to eq([])
      expect(results.apply('0.label', property_resolver: :all)).to eq(['label for widget'])
    end

    it 'does not share policies between threads' do
      inside = Queue.new
      release = Queue.new
      blocked = false
      blocking_policy = lambda do |_object, _name|
        unless blocked
          blocked = true
          inside << true
          release.pop
        end
        true
      end
      object = poro_class.new('widget')
      thread = Thread.new { Enumpath.apply('label', object, property_resolver: blocking_policy) }
      thread.report_on_exception = false
      Timeout.timeout(5) { inside.pop }
      # The other thread is paused inside its callable policy; this thread still uses the default.
      expect(Enumpath.apply('label', object)).to eq([])
      release << true
      expect(Timeout.timeout(5) { thread.value }).to eq(['label for widget'])
    end
  end
end
