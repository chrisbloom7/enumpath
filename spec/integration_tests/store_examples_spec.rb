# frozen_string_literal: true

RSpec.describe 'Store Examples' do
  let(:store) { { store: { book: books, bicycle: bicycle } } }
  let(:books) { [book1, book2, book3, book4] }
  let(:book1) { { category: 'reference', author: 'Nigel Rees', title: 'Sayings of the Century', price: 8.95 } }
  let(:book2) { { category: 'fiction', author: 'Evelyn Waugh', title: 'Sword of Honour', price: 12.99 } }
  let(:book3) do
    { category: 'fiction', author: 'Herman Melville', title: 'Moby Dick', isbn: '0-553-21311-3', price: 8.99 }
  end
  let(:book4) do
    { category: 'fiction', author: 'J. R. R. Tolkien', title: 'The Lord of the Rings', isbn: '0-395-19395-8',
      price: 22.99 }
  end
  let(:bicycle) { { color: 'red', price: 19.95 } }
  let(:result_type) { :value }
  let(:subject) { Enumpath.apply(path, store, result_type: result_type) }

  # Original examples from http://goessner.net/articles/JsonPath/
  describe 'from the original specification' do
    context 'when the path is $.store.book[0].title' do
      let(:path) { '$.store.book[0].title' }

      it 'returns the title of the first book' do
        expect(subject).to contain_exactly(book1[:title])
      end

      context 'when the result type is :path' do
        let(:result_type) { :path }

        it 'returns the path to the title of the first book' do
          expect(subject).to contain_exactly("$['store']['book'][0]['title']")
        end
      end
    end

    context "when the path is $['store']['book'][0]['title']" do
      let(:path) { "$['store']['book'][0]['title']" }

      it 'returns the title of the first book' do
        expect(subject).to contain_exactly(book1[:title])
      end

      context 'when the result type is :path' do
        let(:result_type) { :path }

        it 'returns the path to the title of the first book' do
          expect(subject).to contain_exactly("$['store']['book'][0]['title']")
        end
      end
    end

    context 'when the path is $.store.book[*].author' do
      let(:path) { '$.store.book[*].author' }

      it 'returns the authors of all books in the store' do
        expect(subject).to contain_exactly(book1[:author], book2[:author], book3[:author], book4[:author])
      end

      context 'when the result type is :path' do
        let(:result_type) { :path }

        it 'returns the path to the authors of all books in the store' do
          expect(subject).to contain_exactly(
            "$['store']['book'][0]['author']",
            "$['store']['book'][1]['author']",
            "$['store']['book'][2]['author']",
            "$['store']['book'][3]['author']"
          )
        end
      end
    end

    context 'when the path is $..author' do
      let(:path) { '$..author' }

      it 'returns all authors' do
        expect(subject).to contain_exactly(book1[:author], book2[:author], book3[:author], book4[:author])
      end

      context 'when the result type is :path' do
        let(:result_type) { :path }

        it 'returns the path to all authors' do
          expect(subject).to contain_exactly(
            "$['store']['book'][0]['author']",
            "$['store']['book'][1]['author']",
            "$['store']['book'][2]['author']",
            "$['store']['book'][3]['author']"
          )
        end
      end
    end

    context 'when the path is $.store.*' do
      let(:path) { '$.store.*' }

      it 'returns all things in the store' do
        expect(subject).to contain_exactly(books, bicycle)
      end

      context 'when the result type is :path' do
        let(:result_type) { :path }

        it 'returns the path to each thing in the store' do
          expect(subject).to contain_exactly(
            "$['store']['bicycle']",
            "$['store']['book']"
          )
        end
      end
    end

    context 'when the path is $.store..price' do
      let(:path) { '$.store..price' }

      it 'returns the price of everything in the store' do
        expect(subject).to contain_exactly(book1[:price], book2[:price], book3[:price], book4[:price], bicycle[:price])
      end

      context 'when the result type is :path' do
        let(:result_type) { :path }

        it 'returns the path to the price of everything in the store' do
          expect(subject).to contain_exactly(
            "$['store']['bicycle']['price']",
            "$['store']['book'][0]['price']",
            "$['store']['book'][1]['price']",
            "$['store']['book'][2]['price']",
            "$['store']['book'][3]['price']"
          )
        end
      end
    end

    context 'when the path is $..book[2]' do
      let(:path) { '$..book[2]' }

      it 'returns the third book' do
        expect(subject).to contain_exactly(book3)
      end

      context 'when the result type is :path' do
        let(:result_type) { :path }

        it 'returns the path to the third book' do
          expect(subject).to contain_exactly("$['store']['book'][2]")
        end
      end
    end

    context 'when the path is $..book[(@.length-1)]' do
      let(:path) { '$..book[(@.length-1)]' }

      it 'returns the last book in order' do
        expect(subject).to contain_exactly(book4)
      end

      context 'when the result type is :path' do
        let(:result_type) { :path }

        it 'returns the path to the last book in order' do
          expect(subject).to contain_exactly("$['store']['book'][3]")
        end
      end
    end

    context 'when the path is $..book[-1:]' do
      let(:path) { '$..book[-1:]' }

      it 'returns the last book in order' do
        expect(subject).to contain_exactly(book4)
      end

      context 'when the result type is :path' do
        let(:result_type) { :path }

        it 'returns the path to the last book in order' do
          expect(subject).to contain_exactly("$['store']['book'][3]")
        end
      end
    end

    context 'when the path is $..book[0,1]' do
      let(:path) { '$..book[0,1]' }

      it 'returns the first two books' do
        expect(subject).to contain_exactly(book1, book2)
      end

      context 'when the result type is :path' do
        let(:result_type) { :path }

        it 'returns the path to the first two books' do
          expect(subject).to contain_exactly(
            "$['store']['book'][0]",
            "$['store']['book'][1]"
          )
        end
      end
    end

    context 'when the path is $..book[:2]' do
      let(:path) { '$..book[:2]' }

      it 'returns the first two books' do
        expect(subject).to contain_exactly(book1, book2)
      end

      context 'when the result type is :path' do
        let(:result_type) { :path }

        it 'returns the path to the first two books' do
          expect(subject).to contain_exactly(
            "$['store']['book'][0]",
            "$['store']['book'][1]"
          )
        end
      end
    end

    context 'when the path is $..book[?(@.isbn)]' do
      let(:path) { '$..book[?(@.isbn)]' }

      it 'returns all books with an isbn number' do
        expect(subject).to contain_exactly(book3, book4)
      end

      context 'when the result type is :path' do
        let(:result_type) { :path }

        it 'returns the path to all books with an isbn number' do
          expect(subject).to contain_exactly(
            "$['store']['book'][2]",
            "$['store']['book'][3]"
          )
        end
      end
    end

    context 'when the path is $..book[?(@.price < 10)]' do
      let(:path) { '$..book[?(@.price < 10)]' }

      it 'returns all books with a price less than 10' do
        expect(subject).to contain_exactly(book1, book3)
      end

      context 'when the result type is :path' do
        let(:result_type) { :path }

        it 'returns the path to all books with a price less than 10' do
          expect(subject).to contain_exactly(
            "$['store']['book'][0]",
            "$['store']['book'][2]"
          )
        end
      end
    end

    context 'when the path is $..*' do
      let(:path) { '$..*' }

      it 'returns all members of the enumerable' do
        expect(subject).to contain_exactly(
          store[:store], books, bicycle, book1, book2, book3, book4,
          book1[:category], book1[:author], book1[:title], book1[:price],
          book2[:category], book2[:author], book2[:title], book2[:price],
          book3[:category], book3[:author], book3[:title], book3[:isbn], book3[:price],
          book4[:category], book4[:author], book4[:title], book4[:isbn], book4[:price],
          bicycle[:color], bicycle[:price]
        )
      end

      context 'when the result type is :path' do
        let(:result_type) { :path }

        it 'returns the path to all members of the enumerable' do
          expect(subject).to contain_exactly(
            "$['store']",
            "$['store']['bicycle']",
            "$['store']['bicycle']['color']",
            "$['store']['bicycle']['price']",
            "$['store']['book']",
            "$['store']['book'][0]",
            "$['store']['book'][0]['category']",
            "$['store']['book'][0]['author']",
            "$['store']['book'][0]['title']",
            "$['store']['book'][0]['price']",
            "$['store']['book'][1]",
            "$['store']['book'][1]['category']",
            "$['store']['book'][1]['author']",
            "$['store']['book'][1]['title']",
            "$['store']['book'][1]['price']",
            "$['store']['book'][2]",
            "$['store']['book'][2]['category']",
            "$['store']['book'][2]['author']",
            "$['store']['book'][2]['title']",
            "$['store']['book'][2]['price']",
            "$['store']['book'][2]['isbn']",
            "$['store']['book'][3]",
            "$['store']['book'][3]['category']",
            "$['store']['book'][3]['author']",
            "$['store']['book'][3]['title']",
            "$['store']['book'][3]['price']",
            "$['store']['book'][3]['isbn']"
          )
        end
      end
    end
  end
end
