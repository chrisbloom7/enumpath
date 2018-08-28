# frozen_string_literal: true

RSpec.describe Enumpath::Operator do
  let(:wildcard) { '*' }
  let(:recursive_descent) { '..' }
  let(:union) { 'first,last' }
  let(:filter_expression) { '?(@.title)' }
  let(:slice) { '1:4:2' }
  let(:child) { 'name' }

  describe '.detect' do
    it 'detects child operators' do
      expect(described_class.detect(child, { name: []})).to be_an_instance_of(Enumpath::Operator::Child)
    end

    it 'detects wildcard operators' do
      expect(described_class.detect(wildcard, [])).to be_an_instance_of(Enumpath::Operator::Wildcard)
    end

    it 'detects recursive descent operators' do
      expect(described_class.detect(recursive_descent, [])).to be_an_instance_of(Enumpath::Operator::RecursiveDescent)
    end

    it 'detects union operators' do
      expect(described_class.detect(union, [])).to be_an_instance_of(Enumpath::Operator::Union)
    end

    it 'detects filter expression operators' do
      expect(described_class.detect(filter_expression, [])).to be_an_instance_of(Enumpath::Operator::FilterExpression)
    end

    it 'detects slice operators' do
      expect(described_class.detect(slice, [])).to be_an_instance_of(Enumpath::Operator::Slice)
    end
  end
end
