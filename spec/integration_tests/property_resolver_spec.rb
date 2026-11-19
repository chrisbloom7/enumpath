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
      expect { Enumpath.apply('length', [], property_resolver: :readers) }
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
