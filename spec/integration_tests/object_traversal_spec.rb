# frozen_string_literal: true

# These examples mirror the "Object traversal" section of the README. Keep them in sync.
begin
  require 'ostruct'
rescue LoadError
  # ostruct is a bundled gem (not a default gem) on Ruby 4.0+ and is not part of this gem's bundle there
  OSTRUCT_AVAILABLE = false
else
  OSTRUCT_AVAILABLE = true
end

RSpec.describe 'Object traversal' do
  describe 'a symbol-keyed hash' do
    let(:order) do
      { customer: { name: 'Ada' }, items: [{ sku: 'A1', qty: 2 }, { sku: 'B2', qty: 1 }] }
    end

    it 'resolves a wildcard over symbol keys' do
      expect(Enumpath.apply('items.*.sku', order)).to eq(%w[A1 B2])
    end

    it 'resolves a filter over symbol keys' do
      expect(Enumpath.apply('items[?(@.qty > 1)].sku', order)).to eq(['A1'])
    end
  end

  describe 'a Struct' do
    let(:point) { Struct.new(:x, :y) }
    let(:route) { { stops: [point.new(1, 2), point.new(3, 4)] } }

    it 'resolves members inside a symbol-keyed hash' do
      expect(Enumpath.apply('stops.*.x', route)).to eq([1, 3])
    end

    it 'resolves a relative index followed by a member' do
      expect(Enumpath.apply('stops.-1.y', route)).to eq([4])
    end
  end

  describe 'a plain object with attr_readers' do
    let(:author_class) do
      Class.new do
        attr_reader :name, :books

        def initialize(name, books)
          @name = name
          @books = books
        end

        def label
          "#{name} (#{books.length} books)"
        end
      end
    end
    let(:library) do
      { authors: [author_class.new('Le Guin', %w[Earthsea Dispossessed]), author_class.new('Butler', %w[Kindred])] }
    end

    it 'reads attr_readers under the default :safe policy' do
      expect(Enumpath.apply('authors.*.name', library)).to eq(['Le Guin', 'Butler'])
    end

    it 'calls allowlisted methods on the values it reads' do
      expect(Enumpath.apply('authors.0.books.length', library)).to eq([2])
    end

    it 'does not call a computed reader under :safe' do
      expect(Enumpath.apply('authors.*.label', library)).to eq([])
    end

    it 'calls a computed reader under property_resolver: :readers' do
      expect(Enumpath.apply('authors.*.label', library, property_resolver: :readers))
        .to eq(['Le Guin (2 books)', 'Butler (1 books)'])
    end
  end

  describe 'an OpenStruct' do
    before { skip 'ostruct is not available in this bundle' unless OSTRUCT_AVAILABLE }

    let(:config) { OpenStruct.new(db: OpenStruct.new(host: 'localhost', port: 5432)) }

    it 'resolves fields under the default :safe policy' do
      expect(Enumpath.apply('db.host', config)).to eq(['localhost'])
    end

    it 'resolves fields under property_resolver: :readers' do
      expect(Enumpath.apply('db.host', config, property_resolver: :readers)).to eq(['localhost'])
    end
  end
end
