require 'rails_helper'

RSpec.describe Captain::PerformanceMonitoringService do
  let(:mock_span) { double('Span') }
  let(:mock_usage) { double('Usage', input_tokens: 100, output_tokens: 50) }
  let(:mock_result) do
    double('Result', usage: mock_usage, reasoning: 'Model thought process...')
  end

  let(:service) do
    described_class.new(
      assistant_id: 1,
      conversation_id: 10,
      model: 'glm-5',
      result: mock_result,
      trace_context: { root_span: mock_span }
    )
  end

  describe '#track' do
    before do
      allow(ChatwootApp).to receive(:otel_enabled?).and_return(true)
      allow(mock_span).to receive(:set_attribute)
    end

    it 'tracks model and provider' do
      service.track

      expect(mock_span).to have_received(:set_attribute).with('gen_ai.provider', 'zai')
      expect(mock_span).to have_received(:set_attribute).with('gen_ai.model', 'glm-5')
    end

    it 'tracks usage tokens' do
      service.track

      expect(mock_span).to have_received(:set_attribute).with('gen_ai.usage.input_tokens', 100)
      expect(mock_span).to have_received(:set_attribute).with('gen_ai.usage.output_tokens', 50)
    end

    context 'when OTEL disabled' do
      before do
        allow(ChatwootApp).to receive(:otel_enabled?).and_return(false)
      end

      it 'does not track' do
        service.track
        expect(mock_span).not_to have_received(:set_attribute)
      end
    end
  end

  describe '#model_family' do
    it 'identifies GLM models' do
      expect(service.send(:model_family, 'glm-5')).to eq('glm')
      expect(service.send(:model_family, 'glm-4.6')).to eq('glm')
    end

    it 'identifies specialized models' do
      expect(service.send(:model_family, 'glm-ocr')).to eq('glm-ocr')
      expect(service.send(:model_family, 'glm-asr-2512')).to eq('glm-asr')
    end
  end

  describe '#model_tier' do
    it 'classifies models by tier' do
      expect(service.send(:model_tier, 'glm-5')).to eq('flagship')
      expect(service.send(:model_tier, 'glm-4.6')).to eq('premium')
      expect(service.send(:model_tier, 'glm-ocr')).to eq('specialized')
    end
  end

  describe '.track_assistant_response' do
    before do
      allow(ChatwootApp).to receive(:otel_enabled?).and_return(true)
      allow_any_instance_of(described_class).to receive(:track)
    end

    it 'creates service and tracks' do
      expect_any_instance_of(described_class).to receive(:track)

      described_class.track_assistant_response(
        assistant_id: 1,
        conversation_id: 10,
        model: 'glm-5',
        result: mock_result,
        trace_context: { root_span: mock_span }
      )
    end
  end
end
