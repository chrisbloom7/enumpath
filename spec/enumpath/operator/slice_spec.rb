# frozen_string_literal: true

require 'shared_examples/operator/base'

RSpec.describe Enumpath::Operator::Slice do
  let(:operator) { '0:10:2' }
  let(:instance) { described_class.new(operator) }

  it_behaves_like 'an operator inheriting from Enumpath::Operator::Base', '1:4:2'

  describe '.detect?' do
    context 'when the operator includes a numeric start, length, and step' do
      it 'returns true' do
        expect(described_class.detect?(operator)).to be_truthy
      end
    end

    context 'when the operator includes only a numeric start and length' do
      let(:operator) { '1:4' }

      it 'returns true' do
        expect(described_class.detect?(operator)).to be_truthy
      end
    end

    context 'when the operator includes only a numeric length and step' do
      let(:operator) { ':4:2' }

      it 'returns true' do
        expect(described_class.detect?(operator)).to be_truthy
      end
    end

    context 'when the operator includes only a numeric start and step' do
      let(:operator) { '1::2' }

      it 'returns true' do
        expect(described_class.detect?(operator)).to be_truthy
      end
    end

    context 'when the operator includes only a numeric start' do
      let(:operator) { '1:' }

      it 'returns true' do
        expect(described_class.detect?(operator)).to be_truthy
      end
    end

    context 'true when the operator includes only a numeric length' do
      let(:operator) { ':2' }

      it 'returns true' do
        expect(described_class.detect?(operator)).to be_truthy
      end
    end

    context 'when the operator includes only a numeric step' do
      let(:operator) { '::2' }

      it 'returns true' do
        expect(described_class.detect?(operator)).to be_truthy
      end
    end

    it 'returns false otherwise' do
      expect(described_class.detect?('a:b:c')).to be_falsey
      expect(described_class.detect?('1:b')).to be_falsey
      expect(described_class.detect?(':b:2')).to be_falsey
      expect(described_class.detect?('5.0:3')).to be_falsey
      expect(described_class.detect?('')).to be_falsey
    end
  end

  describe '#apply' do
    let(:remaining_path) { [] }
    let(:enum) { %w[1 2 3 4 5 6 7 8 9 10] }
    let(:resolved_path) { ['numbers'] }
    let(:subject) { ->(block) { instance.apply(remaining_path, enum, resolved_path, &block) } }

    context 'when the operator includes a numeric start, length, and step' do
      it 'yields to the given block for each key of the enumerable from start up to length at step increments' do
        expect { |block| subject[block] }.to yield_control.exactly(5).times
      end

      it 'passes remaining_path with each key prepended, enumerable, and resolved_path' do
        expect { |block| subject[block] }.to yield_successive_args(
          [['0'] + remaining_path, enum, resolved_path],
          [['2'] + remaining_path, enum, resolved_path],
          [['4'] + remaining_path, enum, resolved_path],
          [['6'] + remaining_path, enum, resolved_path],
          [['8'] + remaining_path, enum, resolved_path]
        )
      end
    end

    context 'when the operator includes only a numeric start and length' do
      let(:operator) { '1:4' }

      # Given keys 0..9, starting at index 1 and stopping at (before) index 4 gives us indexes 1,2, and 3
      it 'yields to the given block for each key of the enumerable from start up to length at step increments' do
        expect { |block| subject[block] }.to yield_successive_args(
          [['1'] + remaining_path, enum, resolved_path],
          [['2'] + remaining_path, enum, resolved_path],
          [['3'] + remaining_path, enum, resolved_path]
        )
      end
    end

    context 'when the operator includes only a numeric length and step' do
      let(:operator) { ':4:2' }

      # Given keys 0..9, starting at index 0 (implicit) and stopping at (before) index 4, collecting every 2 items
      # gives us indexes 0 and 2
      it 'yields to the given block for each key of the enumerable from start up to length at step increments' do
        expect { |block| subject[block] }.to yield_successive_args(
          [['0'] + remaining_path, enum, resolved_path],
          [['2'] + remaining_path, enum, resolved_path]
        )
      end
    end

    context 'when the operator includes only a numeric start and step' do
      let(:operator) { '1::2' }

      # Given keys 0..9, starting at index 1 and through the end (implicit), collecting every 2 items
      # gives us indexes 1, 3, 5, 7, and 9
      it 'yields to the given block for each key of the enumerable from start up to length at step increments' do
        expect { |block| subject[block] }.to yield_successive_args(
          [['1'] + remaining_path, enum, resolved_path],
          [['3'] + remaining_path, enum, resolved_path],
          [['5'] + remaining_path, enum, resolved_path],
          [['7'] + remaining_path, enum, resolved_path],
          [['9'] + remaining_path, enum, resolved_path]
        )
      end
    end

    context 'when the operator includes only a numeric start' do
      let(:operator) { '1:' }

      # Given keys 0..9, starting at index 1 and through the end (implicit) gives us indexes 0 - 9
      it 'yields to the given block for each key of the enumerable from start up to length at step increments' do
        expect { |block| subject[block] }.to yield_successive_args(
          [['1'] + remaining_path, enum, resolved_path],
          [['2'] + remaining_path, enum, resolved_path],
          [['3'] + remaining_path, enum, resolved_path],
          [['4'] + remaining_path, enum, resolved_path],
          [['5'] + remaining_path, enum, resolved_path],
          [['6'] + remaining_path, enum, resolved_path],
          [['7'] + remaining_path, enum, resolved_path],
          [['8'] + remaining_path, enum, resolved_path],
          [['9'] + remaining_path, enum, resolved_path]
        )
      end
    end

    context 'true when the operator includes only a numeric length' do
      let(:operator) { ':2' }

      # Given keys 0..9, starting at index 0 (implicit) and up to length gives us indexes 0 and 1
      it 'yields to the given block for each key of the enumerable from start up to length at step increments' do
        expect { |block| subject[block] }.to yield_successive_args(
          [['0'] + remaining_path, enum, resolved_path],
          [['1'] + remaining_path, enum, resolved_path]
        )
      end
    end

    context 'when the operator includes only a numeric step' do
      let(:operator) { '::2' }

      # Given keys 0..9, starting at index 0 (implicit) and through the end (implicit), collecting
      # every 2 items gives us indexes 0, 2, 4, 6, 8
      it 'yields to the given block for each key of the enumerable from start up to length at step increments' do
        expect { |block| subject[block] }.to yield_successive_args(
          [['0'] + remaining_path, enum, resolved_path],
          [['2'] + remaining_path, enum, resolved_path],
          [['4'] + remaining_path, enum, resolved_path],
          [['6'] + remaining_path, enum, resolved_path],
          [['8'] + remaining_path, enum, resolved_path]
        )
      end
    end
  end
end
