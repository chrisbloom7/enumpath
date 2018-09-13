# frozen_string_literal: true

require 'shared_examples/operator/base'

RSpec.describe Enumpath::Operator::FilterExpression do
  let(:operator) { '?(@.category == \'fiction\')' }
  let(:instance) { described_class.new(operator) }

  it_behaves_like 'an operator inheriting from Enumpath::Operator::Base', '?(@.author)'

  describe '.detect?' do
    it 'returns true when the operator matches' do
      expect(described_class.detect?(operator)).to be_truthy
      expect(described_class.detect?('?(@.author)')).to be_truthy
      expect(described_class.detect?('?(@.name.first == \'Ted\')')).to be_truthy
      expect(described_class.detect?('?()')).to be_truthy
    end

    it 'returns false otherwise' do
      expect(described_class.detect?('(@.author)')).to be_falsey
      expect(described_class.detect?('()')).to be_falsey
      expect(described_class.detect?('')).to be_falsey
    end
  end

  describe '#apply' do
    let(:remaining_path) { [] }
    let(:enum) { books }
    let(:books) { [book1, book2, book3, book4] }
    let(:book1) { { category: 'reference', author: 'Nigel Rees', title: 'Sayings of the Century', price: 8.95 } }
    let(:book2) { { category: 'fiction', author: 'Evelyn Waugh', title: 'Sword of Honour', sku: '6789', price: 12.99 } }
    let(:book3) { { category: 'fiction', author: 'Herman Melville', title: 'Moby Dick', sku: '1234', price: 8.99 } }
    let(:book4) { { category: 'fiction', author: 'J. R. R. Tolkien', title: 'Lord of the Rings', price: 22 } }
    let(:resolved_path) { %w[store book] }
    let(:subject) { ->(block) { instance.apply(remaining_path, enum, resolved_path, &block) } }

    context 'when the expression includes a comparison operator' do
      context 'when members of the enumerator pass the filter' do
        it 'yields to the given block for each key of the matching members' do
          expect { |block| subject[block] }.to yield_control.exactly(3).times
        end

        context 'when the property is just "@"' do
          let(:enum) { %w[reference fiction] }
          let(:operator) { '?(@ == \'fiction\')' }

          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_with_args(
              remaining_path, 'fiction', resolved_path + ['1']
            )
          end
        end

        context 'when the operator is `==`' do
          it 'passes remaining_path with the key prepended, enumerable, and resolved_path' do
            expect { |block| subject[block] }.to yield_successive_args(
              [remaining_path, enum[1], resolved_path + ['1']],
              [remaining_path, enum[2], resolved_path + ['2']],
              [remaining_path, enum[3], resolved_path + ['3']]
            )
          end
        end

        context 'when the operator is `!=`' do
          let(:operator) { '?(@.category != \'fiction\')' }

          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_with_args(
              remaining_path, enum[0], resolved_path + ['0']
            )
          end
        end

        context 'when the operator is `>`' do
          let(:operator) { '?(@.price > 9)' }

          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_successive_args(
              [remaining_path, enum[1], resolved_path + ['1']],
              [remaining_path, enum[3], resolved_path + ['3']]
            )
          end
        end

        context 'when the operator is `<`' do
          let(:operator) { '?(@.sku < \'12345\')' }

          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_with_args(
              remaining_path, enum[2], resolved_path + ['2']
            )
          end
        end

        context 'when the operator is `>=`' do
          let(:operator) { '?(@.price >= 12.99)' }

          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_successive_args(
              [remaining_path, enum[1], resolved_path + ['1']],
              [remaining_path, enum[3], resolved_path + ['3']]
            )
          end
        end

        context 'when the operator is `=~`' do
          let(:operator) { '?(@.author =~ /R/)' }

          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_successive_args(
              [remaining_path, enum[0], resolved_path + ['0']],
              [remaining_path, enum[3], resolved_path + ['3']]
            )
          end

          context 'when the operator is not a regular expression' do
            let(:operator) { '?(@.author =~ Herman)' }

            it 'does not yields to the given block' do
              expect { |block| subject[block] }.not_to yield_control
            end
          end
        end

        context 'when the operator is `!~`' do
          let(:operator) { '?(@.author !~ /w/i)' }

          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_successive_args(
              [remaining_path, enum[0], resolved_path + ['0']],
              [remaining_path, enum[2], resolved_path + ['2']],
              [remaining_path, enum[3], resolved_path + ['3']]
            )
          end
        end
      end

      context 'when no members of the enumerator pass the filter' do
        let(:operator) { '?(@.price > 50)' }

        it 'does not yields to the given block' do
          expect { |block| subject[block] }.not_to yield_control
        end
      end

      context 'when the operator does not describe a valid path' do
        let(:operator) { '?(@.quantity > 50)' }

        it 'does not yields to the given block' do
          expect { |block| subject[block] }.not_to yield_control
        end
      end
    end

    context 'when the expression does not include a comparison operator' do
      let(:operator) { '?(@.in_stock)' }
      let(:book1) { { in_stock: 'yes!' } }
      let(:book2) { { in_stock: nil } }
      let(:book3) { { in_stock: false } }
      let(:book4) { { in_stock: true } }

      context 'when members of the enumerator pass the filter' do
        it 'yields to the given block for each key that is truthy' do
          expect { |block| subject[block] }.to yield_control.twice
        end

        it 'passes remaining_path with the result prepended, enumerable, and resolved_path' do
          expect { |block| subject[block] }.to yield_successive_args(
            [remaining_path, enum[0], resolved_path + ['0']],
            [remaining_path, enum[3], resolved_path + ['3']]
          )
        end

        context 'when the property is just "@"' do
          let(:enum) { %w[reference fiction] }
          let(:operator) { '?(@)' }

          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_successive_args(
              [remaining_path, 'reference', resolved_path + ['0']],
              [remaining_path, 'fiction', resolved_path + ['1']]
            )
          end
        end
      end

      context 'when no members of the enumerator pass the filter' do
        let(:book1) { { in_stock: false } }
        let(:book4) { { in_stock: false } }

        it 'does not yields to the given block' do
          expect { |block| subject[block] }.not_to yield_control
        end
      end

      context 'when the operator does not describe a valid path' do
        let(:operator) { '?(@.quantity)' }

        it 'does not yields to the given block' do
          expect { |block| subject[block] }.not_to yield_control
        end
      end
    end

    context 'when the expression includes a logical operator' do
      let(:operator) { '?(@.price > 8.95 && @.price < 22)' }

      context 'when both exressions pass' do
        it 'yields to the given block with the correct arguments for any member that passes' do
          expect { |block| subject[block] }.to yield_successive_args(
            [remaining_path, enum[1], resolved_path + ['1']],
            [remaining_path, enum[2], resolved_path + ['2']]
          )
        end
      end

      context 'when both expressions fail' do
        let(:operator) { '?(@.price < 1 && @.author == \'Ted\')' }

        it 'does not yields to the given block' do
          expect { |block| subject[block] }.not_to yield_control
        end
      end

      context 'when only one exression passes' do
        let(:operator) { '?(@.price > 1 && @.author == \'Ted\')' }

        it 'does not yields to the given block' do
          expect { |block| subject[block] }.not_to yield_control
        end
      end

      context 'when the operator is `||`' do
        let(:operator) { '?(@.price == 8.95 || @.price == 12.99)' }

        context 'when both expressions pass' do
          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_successive_args(
              [remaining_path, enum[0], resolved_path + ['0']],
              [remaining_path, enum[1], resolved_path + ['1']]
            )
          end
        end

        context 'when both expressions fail' do
          let(:operator) { '?(@.price == 7.95 || @.price == 11.99)' }

          it 'does not yields to the given block' do
            expect { |block| subject[block] }.not_to yield_control
          end
        end

        context 'when at least one exression passes' do
          let(:operator) { '?(@.price == 8.95 || @.price == 11.99)' }

          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_with_args(
              remaining_path, enum[0], resolved_path + ['0']
            )
          end
        end
      end

      context 'when the operator includes more than one logical operator' do
        let(:operator) { '?(@.price > 1 && @.author =~ /Nigel/ && @.category != \'fiction\')' }

        context 'when all expressions pass' do
          it 'yields to the given block with the correct arguments' do
            expect { |block| subject[block] }.to yield_with_args(
              remaining_path, enum[0], resolved_path + ['0']
            )
          end
        end

        context 'when all expressions fail' do
          let(:operator) { '?(@.price < 1 && @.author == \'Ted\' && @.category == \'mystery\')' }

          it 'does not yields to the given block' do
            expect { |block| subject[block] }.not_to yield_control
          end
        end

        context 'when at least one exression fails' do
          let(:operator) { '?(@.price > 1 && @.author =~ /Nigel/ && @.category == \'fiction\')' }

          it 'does not yields to the given block' do
            expect { |block| subject[block] }.not_to yield_control
          end
        end

        context 'when the operator is `||`' do
          let(:operator) { '?(@.price == 22 || @.sku || @.category == \'reference\')' }

          context 'when all expressions pass' do
            it 'yields to the given block with the correct arguments' do
              expect { |block| subject[block] }.to yield_successive_args(
                [remaining_path, enum[0], resolved_path + ['0']],
                [remaining_path, enum[1], resolved_path + ['1']],
                [remaining_path, enum[2], resolved_path + ['2']],
                [remaining_path, enum[3], resolved_path + ['3']]
              )
            end
          end

          context 'when all expressions fail' do
            let(:operator) { '?(@.price < 1 || @.author =~ /King/ || @.category == \'mystery\')' }

            it 'does not yields to the given block' do
              expect { |block| subject[block] }.not_to yield_control
            end
          end

          context 'when at least one exression passes' do
            let(:operator) { '?(@.price > 1 || @.author =~ /King/ || @.category == \'mystery\')' }

            it 'yields to the given block with the correct arguments' do
              expect { |block| subject[block] }.to yield_successive_args(
                [remaining_path, enum[0], resolved_path + ['0']],
                [remaining_path, enum[1], resolved_path + ['1']],
                [remaining_path, enum[2], resolved_path + ['2']],
                [remaining_path, enum[3], resolved_path + ['3']]
              )
            end
          end
        end
      end
    end
  end
end
