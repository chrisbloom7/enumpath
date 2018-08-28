# frozen_string_literal: true

RSpec.shared_examples 'an operator inheriting from Enumpath::Operator::Base' do |*detect_args|
  let(:operator) { detect_args.first }
  let(:instance) { described_class.new(operator) }
  let(:remaining_segments) { [] }
  let(:enum) { [] }
  let(:current_path) { [] }

  it 'implements .detect?' do
    expect { described_class.detect?(*detect_args) }.not_to raise_error
  end

  it 'implements #apply' do
    expect { instance.apply(remaining_segments, enum, current_path) {} }.not_to raise_error
  end

  it 'exposes the operator via #operator' do
    expect(instance.operator).to eq(operator)
  end

  it 'implements #to_s' do
    expect(instance.to_s).to eq(operator)
  end
end
