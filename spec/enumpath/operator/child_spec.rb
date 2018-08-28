# frozen_string_literal: true

require 'shared_examples/operator/base'

RSpec.describe Enumpath::Operator::Child do
  let(:operator) { 'name' }
  let(:instance) { described_class.new(operator) }

  it_behaves_like 'an operator inheriting from Enumpath::Operator::Base', 'title', [[]]

  describe '.detect?' do
    let(:missing_operator) { 'address' }
    let(:enum) { { name: [] } }
    let(:empty_enum) { {} }

    it 'returns true if we can find something along the path that matches operator' do
      expect(described_class.detect?(operator, enum)).to be_truthy
    end

    it 'returns false otherwise' do
      expect(described_class.detect?(operator, empty_enum)).to be_falsey
      expect(described_class.detect?(missing_operator, enum)).to be_falsey
    end
  end

  describe '#apply' do
    let(:remaining_path) { [] }
    let(:enum) { { name: name } }
    let(:name) { { first: 'Ted', last: 'Barry' } }
    let(:resolved_path) { ['runners', 1, 'personal_info'] }
    let(:subject) { ->(block) { instance.apply(remaining_path, enum, resolved_path, &block) } }

    it 'yields to the given block' do
      expect { |block| subject[block] }.to yield_control.once
    end

    it 'passes remaining_path, the value of the enumerable at operator, and resolved_path plus the operator' do
      expect { |block| subject[block] }.to yield_with_args(remaining_path, name, resolved_path + [operator])
    end

    context 'when the operator does not describe a valid path through enum' do
      let(:operator) { 'job' }

      it 'does not yield to the given block' do
        expect { |block| subject[block] }.not_to yield_control
      end
    end
  end
end
