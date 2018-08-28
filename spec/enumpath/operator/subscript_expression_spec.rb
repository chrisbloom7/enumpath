# frozen_string_literal: true

require 'shared_examples/operator/base'

RSpec.describe Enumpath::Operator::SubscriptExpression do
  let(:operator) { '(@.length-1)' }
  let(:instance) { described_class.new(operator) }

  it_behaves_like 'an operator inheriting from Enumpath::Operator::Base', '(@.length-1)'

  describe '.detect?' do
    it 'returns true when the operator matches' do
      expect(described_class.detect?(operator)).to be_truthy
      expect(described_class.detect?('(@.length)')).to be_truthy
      expect(described_class.detect?('()')).to be_truthy
    end

    it 'returns false otherwise' do
      expect(described_class.detect?('?(@.length)')).to be_falsey
      expect(described_class.detect?('')).to be_falsey
    end
  end

  describe '#apply' do
    let(:remaining_segments) { [] }
    let(:enum) { (2..10).to_a }
    let(:current_path) { ['numbers'] }
    let(:subject) { ->(block) { instance.apply(remaining_segments, enum, current_path, &block) } }

    context 'when the operator includes an arithmetic operator' do
      context 'when the result describes a valid path through enum' do
        it 'yields to the given block' do
          expect { |block| subject[block] }.to yield_control.once
        end

        context 'when the operator is `-`' do
          # length of enumerable is 9. 9-1 = 8
          it 'passes remaining_segments with the result prepended, enumerable, and current_path' do
            expect { |block| subject[block] }.to yield_with_args(
              remaining_segments, enum[8], current_path + ['8']
            )
          end
        end

        context 'when the operator is `+`' do
          let(:operator) { '(@.first + 1)' }

          # enum.first is 2. 2+1 = 3
          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_with_args(
              remaining_segments, enum[3], current_path + ['3']
            )
          end
        end

        context 'when the operator is `*`' do
          let(:operator) { '(@.first * 3)' }

          # enum.first is 2. 2*3 = 6
          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_with_args(
              remaining_segments, enum[6], current_path + ['6']
            )
          end
        end

        context 'when the operator is `/`' do
          let(:operator) { '(@.last / 2)' }

          # enum.last is 10. 10/2 = 5
          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_with_args(
              remaining_segments, enum[5], current_path + ['5']
            )
          end
        end

        context 'when the operator is `%`' do
          let(:operator) { '(@.size % 6)' }

          # enum.size is 9. 9%6 = 3
          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_with_args(
              remaining_segments, enum[3], current_path + ['3']
            )
          end
        end

        context 'when the operator is `**`' do
          let(:operator) { '(@.first ** 3)' }

          # enum.first is 2. 2**3 = 8
          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_with_args(
              remaining_segments, enum[8], current_path + ['8']
            )
          end
        end
      end

      context 'when the result does not describe a valid path through enum' do
        let(:operator) { '(@.length + 1)' }

        # enum.size is 9. enum[9 + 1] == nil
        it 'does not yields to the given block' do
          expect { |block| subject[block] }.not_to yield_control
        end
      end
    end

    context 'when the operator does not include an arithmetic operator' do
      let(:operator) { '(@.first)' }

      context 'when the result describes a valid path through enum' do
        it 'yields to the given block' do
          expect { |block| subject[block] }.to yield_control.once
        end

        # enum.first is 2
        it 'passes remaining_segments with the result prepended, enumerable, and current_path' do
          expect { |block| subject[block] }.to yield_with_args(
            remaining_segments, enum[2], current_path + ['2']
          )
        end
      end

      context 'when the result does not describe a valid path through enum' do
        let(:operator) { '(@.length)' }

        # enum.size is 9. enum[9] == nil
        it 'does not yields to the given block' do
          expect { |block| subject[block] }.not_to yield_control
        end
      end
    end
  end
end
