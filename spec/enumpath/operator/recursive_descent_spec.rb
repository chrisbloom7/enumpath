# frozen_string_literal: true

require 'shared_examples/operator/base'

RSpec.describe Enumpath::Operator::RecursiveDescent do
  let(:operator) { '..' }
  let(:instance) { described_class.new(operator) }

  it_behaves_like 'an operator inheriting from Enumpath::Operator::Base', '..'

  describe '.detect?' do
    it 'returns true when the operator matches' do
      expect(described_class.detect?(operator)).to be_truthy
    end

    it 'returns false otherwise' do
      expect(described_class.detect?('.')).to be_falsey
      expect(described_class.detect?('...')).to be_falsey
      expect(described_class.detect?('')).to be_falsey
    end
  end

  describe '#apply' do
    let(:remaining_path) { [] }
    let(:resolved_path) { ['employees'] }
    let(:subject) { ->(block) { instance.apply(remaining_path, enum, resolved_path, &block) } }

    context 'when the enumerable contains no other enumerables' do
      let(:enum) { [] }

      it 'yields to the given block once for itself' do
        expect { |block| subject[block] }.to yield_control.once
      end

      it 'passes all arguments to the block as-is' do
        expect { |block| subject[block] }.to yield_with_args(remaining_path, enum, resolved_path)
      end
    end

    context 'when the enumerable contains other enumerables' do
      let(:enum) { [enum1, enum2] }
      let(:enum1) { ['I\'m an enumerable!'] }
      let(:enum2) { ['Me too!'] }

      context 'when an item matching a key is an enumerable' do
        it 'yields to the given block for each element in enum, plus once for itself' do
          expect { |block| subject[block] }.to yield_control.thrice
        end

        describe 'for each element in enum it sends' do
          it 'operator prepended to remaining_path, the element of enumerable matching key, ' \
             'and key appended to resolved_path' do
            expect { |block| subject[block] }.to yield_successive_args(
              [remaining_path, enum, resolved_path],
              [['..'] + remaining_path, enum1, resolved_path + [0]],
              [['..'] + remaining_path, enum2, resolved_path + [1]]
            )
          end
        end
      end

      context 'when an item matching a key is not an enumerable' do
        let(:enum2) { 'I\'m not an enumerable!' }

        it 'does not yield the given block for that key' do
          expect { |block| subject[block] }.to yield_successive_args(
            [remaining_path, enum, resolved_path],
            [['..'] + remaining_path, enum1, resolved_path + [0]]
          )
        end
      end
    end
  end
end
