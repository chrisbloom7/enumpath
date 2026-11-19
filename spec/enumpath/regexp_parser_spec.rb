# frozen_string_literal: true

RSpec.describe Enumpath::RegexpParser do
  describe '.parse' do
    it 'parses a slash-delimited literal' do
      expect(described_class.parse('/^Some\s+/')).to eq(/^Some\s+/)
    end

    it 'parses the %r{} form' do
      expect(described_class.parse('%r{a/b}')).to eq(%r{a/b})
    end

    it 'applies the i, m and x flags' do
      parsed = described_class.parse('/a b/imx')
      expect(parsed.options).to eq(Regexp::IGNORECASE | Regexp::MULTILINE | Regexp::EXTENDED)
    end

    it 'accepts the n flag' do
      expect(described_class.parse('/a/n').options & Regexp::NOENCODING).to eq(Regexp::NOENCODING)
    end

    it 'accepts the u flag and ignores it' do
      expect(described_class.parse('/a/u')).to eq(/a/)
    end

    it 'unescapes an escaped delimiter' do
      expect(described_class.parse('/a\/b/')).to eq(%r{a/b})
    end

    it 'keeps other escapes untouched' do
      expect(described_class.parse('/\d+\.\d+/')).to eq(/\d+\.\d+/)
    end

    it 'keeps a backreference intact' do
      expect(described_class.parse('/^(a*)*\1$/')).to eq(/^(a*)*\1$/)
    end

    it 'allows an empty pattern' do
      expect(described_class.parse('//')).to eq(//)
    end

    ['x', '10', ':sym', '"str"', '/', '/abc', 'abc/', '/a/z', '/a/e', '/a/s', '%r{a', '%r(a)', ''].each do |other|
      it "returns nil for #{other.inspect}" do
        expect(described_class.parse(other)).to be_nil
      end
    end

    it 'raises a RegexpError for an invalid pattern' do
      expect { described_class.parse('/(/') }.to raise_error(RegexpError)
    end

    it 'never evaluates the pattern as Ruby code' do
      expect(described_class.parse("/\#{exit}/").source).to eq("\#{exit}")
    end

    it 'does not add String#to_regexp or Regexp#to_regexp' do
      expect('x').not_to respond_to(:to_regexp)
      expect(/x/).not_to respond_to(:to_regexp)
    end
  end
end
