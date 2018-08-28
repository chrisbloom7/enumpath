# frozen_string_literal: true

require 'shared_examples/operator/base'

RSpec.describe Enumpath::Operator::Union do
  let(:operator) { 'first_name,last_name' }
  let(:instance) { described_class.new(operator) }

  it_behaves_like 'an operator inheriting from Enumpath::Operator::Base', 'first,last'

  describe '.detect?' do
    it 'returns true when the operator includes commas and none are at the edges of the operator' do
      expect(described_class.detect?(operator)).to be_truthy
      expect(described_class.detect?('a,b,c')).to be_truthy
    end

    it 'returns false otherwise' do
      expect(described_class.detect?(',b')).to be_falsey
      expect(described_class.detect?('a,')).to be_falsey
      expect(described_class.detect?(',')).to be_falsey
      expect(described_class.detect?('a,b,')).to be_falsey
      expect(described_class.detect?(',b,c')).to be_falsey
      expect(described_class.detect?('')).to be_falsey
    end
  end

  describe '#apply' do
    let(:remaining_segments) { [] }
    let(:enum) { { first_name: first_name, last_name: last_name } }
    let(:first_name) { 'Ted' }
    let(:last_name) { 'Barry' }
    let(:current_path) { ['employees', 1, 'personal_info'] }
    let(:subject) { ->(block) { instance.apply(remaining_segments, enum, current_path, &block) } }

    it 'yields to the given block for each segment of the operator' do
      expect { |block| subject[block] }.to yield_control.twice
    end

    it 'passes remaining_segments with each segment prepended, enumerable, and current_path' do
      expect { |block| subject[block] }.to yield_successive_args(
        [['first_name'] + remaining_segments, enum, current_path],
        [['last_name'] + remaining_segments, enum, current_path]
      )
    end

    context 'when a segment has single quotes around it' do
      let(:operator) { "'first_name'" }

      it 'removes the quotes from around the segment before yielding' do
        expect { |block| subject[block] }.to yield_successive_args(
          [['first_name'] + remaining_segments, enum, current_path]
        )
      end
    end

    context 'when a segment has double quotes around it' do
      let(:operator) { '"first_name"' }

      it 'removes the quotes from around the segment before yielding' do
        expect { |block| subject[block] }.to yield_successive_args(
          [['first_name'] + remaining_segments, enum, current_path]
        )
      end
    end

    context 'when a segment has space around it' do
      let(:operator) { 'first_name , last_name' }

      it 'removes the quotes from around the segment before yielding' do
        expect { |block| subject[block] }.to yield_successive_args(
          [['first_name'] + remaining_segments, enum, current_path],
          [['last_name'] + remaining_segments, enum, current_path]
        )
      end
    end
  end
end
