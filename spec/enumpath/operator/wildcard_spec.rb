# frozen_string_literal: true

require 'shared_examples/operator/base'

RSpec.describe Enumpath::Operator::Wildcard do
  let(:operator) { '*' }
  let(:instance) { described_class.new(operator) }

  it_behaves_like 'an operator inheriting from Enumpath::Operator::Base', '*'

  describe '.detect?' do
    it 'returns true when the operator matches' do
      expect(described_class.detect?(operator)).to be_truthy
    end

    it 'returns false otherwise' do
      expect(described_class.detect?('a*b')).to be_falsey
      expect(described_class.detect?('**')).to be_falsey
      expect(described_class.detect?('')).to be_falsey
    end
  end

  describe '#apply' do
    let(:remaining_path) { [] }
    let(:enum) { [{ first: 'Ted', last: 'Barry' }, { first: 'Kim', last: 'Larry' }] }
    let(:resolved_path) { ['employees'] }
    let(:subject) { ->(block) { instance.apply(remaining_path, enum, resolved_path, &block) } }

    it 'yields to the given block for each element in enum' do
      expect { |block| subject[block] }.to yield_control.twice
    end

    it 'passes remaining_path with each key prepended, enumerable, and resolved_path' do
      expect { |block| subject[block] }.to yield_successive_args(
        [['0'] + remaining_path, enum, resolved_path], [['1'] + remaining_path, enum, resolved_path]
      )
    end
  end
end
