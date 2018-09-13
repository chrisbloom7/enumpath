# frozen_string_literal: true

RSpec.describe Enumpath::Logger do
  let(:subject) { described_class.new }
  let(:logger) { subject.logger }

  describe '.new' do
    it 'creates a an instance of ::Logger.new(STDOUT) by default' do
      expect(::Logger).to receive(:new).with(STDOUT)
      subject
    end
  end

  describe '#log' do
    let(:title) { 'A thing you should know' }
    let(:block) { proc { { a: :b, cd: :e } } }

    before { Enumpath.verbose = true }

    it 'logs the title' do
      logger = double('::Logger').as_null_object
      subject.logger = logger
      subject.log(title, &block)
      expect(logger).to have_received(:<<).with("Enumpath: #{title}\n")
    end

    context 'when Enumpath.verbose is false' do
      before { Enumpath.verbose = false }

      it 'does not log anything' do
        expect(logger).not_to receive(:<<)
        subject.log(title)
      end

      context 'when called with a block' do
        it 'does not call the block' do
          expect { |b| subject.log(title, &b) }.not_to yield_control
        end
      end
    end

    context 'when called with a block' do
      it 'calls the block' do
        expect { |b| subject.log(title, &b) }.to yield_control
      end

      context 'when the block is a Hash' do
        it 'adds the tuples to the output with padded labels' do
          logger = double('::Logger').as_null_object
          subject.logger = logger
          subject.log(title, &block)
          expect(logger).to have_received(:<<).with("a : b\n")
          expect(logger).to have_received(:<<).with("cd: e\n")
        end
      end
    end

    context 'when @level is more than 0' do
      before { subject.level = 1 }

      it 'adds padding to the log messages' do
        logger = double('::Logger').as_null_object
        subject.logger = logger
        subject.log(title, &block)
        expect(logger).to have_received(:<<).with("  Enumpath: #{title}\n")
      end
    end
  end
end
