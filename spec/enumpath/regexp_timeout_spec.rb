# frozen_string_literal: true

RSpec.describe Enumpath::RegexpTimeout do
  let(:backtracking) { /^(a*)*\1$/ }
  let(:hostile_string) { "#{'a' * 28}!" }

  describe '.with_limit' do
    it 'yields and returns the value of the block' do
      expect(described_class.with_limit(1) { :result }).to eq(:result)
    end

    it 'restores the previous limit afterwards, even when the block raises' do
      described_class.with_limit(1) { raise 'boom' } rescue nil # rubocop:disable Style/RescueModifier
      expect(Thread.current[described_class::THREAD_KEY]).to be_nil
    end

    [0, -1, Float::INFINITY, Float::NAN, '1', :fast, Complex(1, 1)].each do |bad|
      it "raises an ArgumentError for #{bad.inspect}" do
        expect { described_class.with_limit(bad) { nil } }.to raise_error(ArgumentError, /regexp_timeout/)
      end
    end

    it 'accepts nil, an integer and a float' do
      [nil, 1, 0.5].each { |ok| expect { described_class.with_limit(ok) { nil } }.not_to raise_error }
    end
  end

  describe '.limit' do
    it 'returns a regular expression with the same pattern and options' do
      limited = described_class.with_limit(1) { described_class.limit(/ab (c|d)/ix) }
      expect(limited.source).to eq('ab (c|d)')
      expect(limited.options & (Regexp::IGNORECASE | Regexp::EXTENDED)).to eq(Regexp::IGNORECASE | Regexp::EXTENDED)
    end

    it 'keeps working with a non-ASCII pattern' do
      limited = described_class.with_limit(1) { described_class.limit(/café/i) }
      expect(limited).to match("CAF\u00c9")
    end

    it 'returns the regular expression itself when there is no limit' do
      expect(described_class.with_limit(nil) { described_class.limit(backtracking) }).to equal(backtracking)
    end

    it 'uses the default limit outside of an Enumpath.apply call' do
      skip 'needs Ruby 3.2 or later' unless described_class::SUPPORTED

      expect(described_class.limit(/a/).timeout).to eq(described_class::DEFAULT)
    end

    context 'when the Ruby supports limits' do
      before { skip 'needs Ruby 3.2 or later' unless described_class::SUPPORTED }

      it 'sets the timeout on the copy' do
        expect(described_class.with_limit(0.25) { described_class.limit(/a/) }.timeout).to eq(0.25)
      end

      it 'makes a pathological match raise instead of hanging' do
        limited = described_class.with_limit(0.05) { described_class.limit(backtracking) }
        expect { limited =~ hostile_string }.to raise_error(described_class::ERROR)
      end

      it 'raises once an earlier match has expired' do
        described_class.with_limit(1) do
          described_class.expire!
          expect { described_class.limit(/a/) }.to raise_error(described_class::ERROR, /earlier/)
        end
      end

      it 'does not leak an expired state into the next call' do
        described_class.with_limit(1) { described_class.expire! }
        expect { described_class.with_limit(1) { described_class.limit(/a/) } }.not_to raise_error
      end
    end
  end
end
