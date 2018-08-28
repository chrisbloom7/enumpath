# frozen_string_literal: true

RSpec.describe Enumpath::Results do
  let(:result_type) { :value }
  let(:subject) { Enumpath::Results.new(result_type: result_type) }
  let(:resolved_path) { %w(story heroes 1) }
  let(:enum) { { name: 'Frodo' } }
  let(:store) { subject.store(resolved_path, enum) }

  it 'is a subclass of Array' do
    expect(subject).to be_a_kind_of(Array)
  end

  describe '.new' do
    it 'exposes the result_type option as #result_type' do
      expect(subject.result_type).to eq(:value)
    end
  end

  describe '#store' do
    it 'adds enum to the result store' do
      expect { store }.to change { subject }.from([]).to([enum])
    end

    context 'when result_type is :path' do
      let(:result_type) { :path }

      it 'adds a path representation of resolved_path to the result store' do
        expect { store }.to change { subject }.from([]).to(["$['story']['heroes'][1]"])
      end

      it 'returns true' do
        expect(store).to be_truthy
      end
    end
  end

  describe '#apply' do
    let(:path) { '$.name' }
    before { store }

    it 'calls Enumpath.apply with the path and the current result store' do
      expect(Enumpath).to receive(:apply).with(path, [enum], {})
      subject.apply(path)
    end

    it 'passes options through to Enumpath.apply' do
      options = { verbose: true }
      expect(Enumpath).to receive(:apply).with(path, [enum], options)
      subject.apply(path, options)
    end
  end
end
