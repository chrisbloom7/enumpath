# frozen_string_literal: true

RSpec.describe Enumpath do
  describe '.logger' do
    it 'is an instance of Enumpath::Logger' do
      expect(Enumpath.logger).to be_a(Enumpath::Logger)
    end
  end

  describe '.log' do
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

  describe '.path_cache' do
    it 'is an instance of MiniCache::Store' do
      expect(Enumpath.path_cache).to be_a(MiniCache::Store)
    end
  end

  describe '.apply' do
    let(:path) { '$' }
    let(:enum) { {} }

    it 'can toggle on verbose mode' do
      Enumpath.verbose = false
      Enumpath.apply(path, enum, verbose: true)
      expect(Enumpath.verbose).to be_truthy
    end

    it 'can toggle off verbose mode' do
      Enumpath.verbose = true
      Enumpath.apply(path, enum, verbose: false)
      expect(Enumpath.verbose).to be_falsey
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
  end
end
