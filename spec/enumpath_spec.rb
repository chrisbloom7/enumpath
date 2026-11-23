# frozen_string_literal: true

RSpec.describe Enumpath do
  describe '.logger' do
    it 'is an instance of Enumpath::Logger' do
      expect(Enumpath.logger).to be_a(Enumpath::Logger)
    end
  end

  describe '.log' do
    context 'when verbose mode is off' do
      it 'does not touch .logger, or evaluate the block' do
        expect(Enumpath.logger).not_to receive(:log)
        expect { |block| Enumpath.log('LOG!', &block) }.not_to yield_control
      end
    end

    context 'when verbose mode is on' do
      before { Enumpath.verbose = true }

      it 'sends log messages to .logger' do
        expect(Enumpath.logger).to receive(:log).with('LOG!')
        Enumpath.log('LOG!')
      end

      context 'with a block' do
        it 'sends the block to .logger' do
          expect(Enumpath.logger).to receive(:log).with('LOG!') do |&block|
            expect(block).to be_a_kind_of(Proc)
          end
          Enumpath.log('LOG!') { 'BLOCK!' }
        end
      end
    end
  end

  describe '.path_cache' do
    it 'is an instance of Enumpath::PathCache' do
      expect(Enumpath.path_cache).to be_a(Enumpath::PathCache)
    end
  end

  describe '.apply' do
    let(:path) { '$' }
    let(:enum) { {} }

    describe 'the :verbose option' do
      let(:seen) { [] }
      let(:probe) { ->(_object, _name) { seen << Enumpath.verbose && false } }

      it 'turns verbose mode on for the call only' do
        Enumpath.apply('x', Object.new, verbose: true, property_resolver: probe)
        expect(seen).to eq([true])
        expect(Enumpath.verbose).to be(false)
      end

      it 'turns verbose mode off for the call only, even when it is on by default' do
        Enumpath.verbose = true
        Enumpath.apply('x', Object.new, verbose: false, property_resolver: probe)
        expect(seen).to eq([false])
        expect(Enumpath.verbose).to be(true)
      end

      it 'uses Enumpath.verbose when the call has no :verbose option' do
        Enumpath.verbose = true
        Enumpath.apply('x', Object.new, property_resolver: probe)
        expect(seen).to eq([true])
      end
    end

    it 'passes the path argument through to Enumpath::Path#new' do
      expect(Enumpath::Path).to receive(:new).with(path, anything).and_call_original
      Enumpath.apply(path, enum)
    end

    it 'passes the :result_type option through to Enumpath::Path#new' do
      result_type = :path
      expect(Enumpath::Path).to receive(:new).with(path, result_type: result_type).and_call_original
      Enumpath.apply(path, enum, result_type: result_type)
    end

    it 'calls #apply with enum on the Enumpath::Path instance' do
      path_instance = double('Enumpath::Path')
      expect(Enumpath::Path).to receive(:new) { path_instance }
      expect(path_instance).to receive(:apply).with(enum)
      Enumpath.apply(path, enum)
    end

    it 'does not modify the options hash' do
      options = { verbose: false, result_type: :value, property_resolver: :none }.freeze
      expect { Enumpath.apply(path, enum, options) }.not_to raise_error
      expect(options).to eq(verbose: false, result_type: :value, property_resolver: :none)
    end

    it 'resolves properties with the :property_resolver option for the duration of the call' do
      expect(Enumpath::Resolver::Property).to receive(:with_policy).with(:all).and_call_original
      expect(Enumpath.apply('length', [1, 2], property_resolver: :all)).to eq([2])
      expect(Enumpath::Resolver::Property.current_policy).to eq(:safe)
    end

    it 'raises ArgumentError for a negative slice step' do
      expect { Enumpath.apply('$[::-1]', [1, 2, 3]) }
        .to raise_error(ArgumentError, 'negative slice steps are not supported')
    end

    it 'raises ArgumentError for an invalid :property_resolver option' do
      expect { Enumpath.apply(path, enum, property_resolver: :bogus) }.to raise_error(ArgumentError, /:bogus/)
    end

    describe 'the :regexp_timeout option' do
      let(:hostile) { Array.new(20) { { s: "#{'a' * 28}!" } } + [{ s: 'ok' }] }
      let(:hostile_path) { '[?(@.s =~ /^(a*)*\\1$/)]' }

      it 'raises ArgumentError for an invalid value' do
        expect { Enumpath.apply(path, enum, regexp_timeout: 0) }.to raise_error(ArgumentError, /regexp_timeout/)
      end

      it 'does not change a regular expression that matches in time' do
        expect(Enumpath.apply('[?(@.s =~ /^o/)]', hostile, regexp_timeout: 0.5)).to eq([{ s: 'ok' }])
      end

      it 'matches normally when the limit is nil' do
        expect(Enumpath.apply('[?(@.s =~ /^o/)]', hostile, regexp_timeout: nil)).to eq([{ s: 'ok' }])
      end

      context 'when the Ruby supports limits' do
        before { skip 'needs Ruby 3.2 or later' unless Enumpath::RegexpTimeout::SUPPORTED }

        it 'matches nothing instead of hanging when a regular expression backtracks without end' do
          expect(Enumpath.apply(hostile_path, hostile, regexp_timeout: 0.05)).to eq([])
        end

        it 'spends at most one limit on the whole call, not one per member' do
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          Enumpath.apply(hostile_path, hostile, regexp_timeout: 0.2)
          expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1.5
        end

        it 'still evaluates the rest of an expression after a regular expression ran out of time' do
          result = Enumpath.apply("[?(@.s =~ /^(a*)*\\1$/ || @.s == 'ok')]", hostile, regexp_timeout: 0.05)
          expect(result).to eq([{ s: 'ok' }])
        end

        it 'applies the limit by default' do
          expect(Enumpath::RegexpTimeout).to receive(:with_limit).with(Enumpath::RegexpTimeout::DEFAULT).and_call_original
          Enumpath.apply(path, enum)
        end
      end
    end
  end
end
