# frozen_string_literal: true

RSpec.describe Enumpath::Resolver::ObjectInspector do
  describe '.application_method?' do
    it 'is true for a method written in Ruby outside of Ruby itself' do
      object = Class.new { define_method(:name) { 'name' } }.new
      expect(described_class.application_method?(object.method(:name))).to be(true)
    end

    it 'is false for a method without a source location' do
      expect(described_class.application_method?(nil)).to be(false)
      expect(described_class.application_method?([].method(:clear))).to be(false)
      expect(described_class.application_method?(instance_double(Method, source_location: []))).to be(false)
    end
  end
end
