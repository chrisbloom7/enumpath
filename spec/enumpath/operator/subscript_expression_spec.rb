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
    let(:remaining_path) { [] }
    let(:enum) { (2..10).to_a }
    let(:resolved_path) { ['numbers'] }
    let(:subject) { ->(block) { instance.apply(remaining_path, enum, resolved_path, &block) } }

    context 'when the operator includes an arithmetic operator' do
      context 'when the result describes a valid path through enum' do
        it 'yields to the given block' do
          expect { |block| subject[block] }.to yield_control.once
        end

        context 'when the operator is `-`' do
          # length of enumerable is 9. 9-1 = 8
          it 'passes remaining_path with the result prepended, enumerable, and resolved_path' do
            expect { |block| subject[block] }.to yield_with_args(
              remaining_path, enum[8], resolved_path + ['8']
            )
          end
        end

        context 'when the operator is `+`' do
          let(:operator) { '(@.first + 1)' }

          # enum.first is 2. 2+1 = 3
          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_with_args(
              remaining_path, enum[3], resolved_path + ['3']
            )
          end
        end

        context 'when the operator is `*`' do
          let(:operator) { '(@.first * 3)' }

          # enum.first is 2. 2*3 = 6
          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_with_args(
              remaining_path, enum[6], resolved_path + ['6']
            )
          end
        end

        context 'when the operator is `/`' do
          let(:operator) { '(@.last / 2)' }

          # enum.last is 10. 10/2 = 5
          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_with_args(
              remaining_path, enum[5], resolved_path + ['5']
            )
          end
        end

        context 'when the operator is `%`' do
          let(:operator) { '(@.size % 6)' }

          # enum.size is 9. 9%6 = 3
          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_with_args(
              remaining_path, enum[3], resolved_path + ['3']
            )
          end
        end

        context 'when the operator is `**`' do
          let(:operator) { '(@.first ** 3)' }

          # enum.first is 2. 2**3 = 8
          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_with_args(
              remaining_path, enum[8], resolved_path + ['8']
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

      context 'when the expression would repeat a string or array too many times' do
        let(:text) { +'abcdefghij' }
        let(:enum) { { name: text, items: [1, 2, 3] } }

        it 'does not repeat a string beyond the size limit' do
          expect(text).not_to receive(:*)
          instance = described_class.new('(@.name * 20000000)')
          expect { |block| instance.apply(remaining_path, enum, resolved_path, &block) }.not_to yield_control
        end

        it 'does not repeat an array beyond the size limit' do
          expect(enum[:items]).not_to receive(:*)
          instance = described_class.new('(@.items * 5000000)')
          expect { |block| instance.apply(remaining_path, enum, resolved_path, &block) }.not_to yield_control
        end

        it 'repeats a string up to the size limit' do
          expect(text).to receive(:*).with(1000).and_call_original # 10 characters * 1000 == 10_000
          described_class.new('(@.name * 1000)').apply(remaining_path, enum, resolved_path) { nil }
        end

        it 'does not repeat a string one step past the size limit' do
          expect(text).not_to receive(:*)
          described_class.new('(@.name * 1001)').apply(remaining_path, enum, resolved_path) { nil }
        end
      end

      context 'when the expression applies `%` to a string' do
        let(:text) { +'%999999999d' } # String#% is `format`, so this would build a huge string
        let(:enum) { { fmt: text } }

        it 'does not call `%`' do
          expect(text).not_to receive(:%)
          instance = described_class.new('(@.fmt % 1)')
          expect { |block| instance.apply(remaining_path, enum, resolved_path, &block) }.not_to yield_control
        end
      end

      context 'when an integer operand does not fit in 64 bits' do
        let(:enum) { [1, 2, 3] }

        it 'matches nothing instead of raising' do
          instance = described_class.new("(@.length * #{'9' * 50})")
          expect { |block| instance.apply(remaining_path, enum, resolved_path, &block) }.not_to yield_control
        end

        it 'accepts the largest 64 bit operand' do
          expect(instance.send(:within_limits?, '*', (2**64) - 1, 3)).to be(true)
          expect(instance.send(:within_limits?, '*', 2**64, 3)).to be(false)
          expect(instance.send(:within_limits?, '+', -(2**64), 3)).to be(false)
        end
      end

      context 'when the expression raises a power' do
        # Checked through the predicate: evaluating an over-limit power would hang the spec
        def allowed?(base, exponent)
          instance.send(:within_limits?, '**', exponent, base)
        end

        it 'allows integer powers whose result fits in 1,024 bits' do
          expect(allowed?(2, 3)).to be(true)
          expect(allowed?(2, 512)).to be(true) # 2 has a bit length of 2, so 2 * 512 == 1_024
          expect(allowed?(0, 2**60)).to be(true)
        end

        it 'rejects integer powers beyond 1,024 bits' do
          expect(allowed?(2, 513)).to be(false)
          expect(allowed?(3, 3_000_000)).to be(false)
          expect(allowed?(3, -3_000_000)).to be(false)
        end

        it 'allows floats, which overflow to Infinity quickly' do
          expect(allowed?(2.5, 3_000_000)).to be(true)
        end

        it 'rejects other kinds of number and non-integer exponents' do
          expect(allowed?(Rational(1, 2), 3)).to be(false)
          expect(allowed?(2, 'a')).to be(false)
        end
      end

      context 'when the expression cannot be evaluated' do
        {
          'divides by zero' => ['(@.length / 0)', [1, 2, 3]],
          'takes a remainder by zero' => ['(@.length % 0)', [1, 2, 3]],
          'adds a string to a number' => ["(@.length + 'a')", [1, 2, 3]],
          'adds a number to a string' => ['(@.id + 1)', { id: '7' }]
        }.each do |description, (expression, data)|
          it "matches nothing instead of raising when it #{description}" do
            instance = described_class.new(expression)
            expect { |block| instance.apply(remaining_path, data, resolved_path, &block) }.not_to yield_control
          end
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
        it 'passes remaining_path with the result prepended, enumerable, and resolved_path' do
          expect { |block| subject[block] }.to yield_with_args(
            remaining_path, enum[2], resolved_path + ['2']
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
