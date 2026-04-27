require 'rails_helper'

RSpec.describe Captain::Llm::EmbeddingService do
  describe '#get_embedding' do
    let(:service) { described_class.new(account_id: 1) }
    let(:content) { 'Есть ли бесплатная парковка?' }
    let(:context) { instance_double('RubyLLM::Context') }
    let(:response) { instance_double('RubyLLM::EmbeddingResponse', vectors: [0.1, 0.2, 0.3]) }

    before do
      allow(context).to receive(:embed).and_return(response)
    end

    it 'uses embedding model from provider config when model is not passed' do
      captured_params = nil
      allow(context).to receive(:embed) do |_input, **params|
        captured_params = params
        response
      end
      allow(Llm::Config).to receive(:embedding_context).and_return([context, 'openrouter', 'baai/bge-m3'])

      result = service.get_embedding(content)

      expect(result).to eq([0.1, 0.2, 0.3])
      expect(captured_params).to include(model: 'baai/bge-m3', provider: 'openrouter', assume_model_exists: true)
      expect(captured_params).not_to have_key(:dimensions)
    end

    it 'passes dimensions only for text-embedding-3 models' do
      captured_params = nil
      allow(context).to receive(:embed) do |_input, **params|
        captured_params = params
        response
      end
      allow(Llm::Config).to receive(:embedding_context).and_return([context, 'openai', 'text-embedding-3-small'])

      service.get_embedding(content)

      expect(captured_params[:dimensions]).to eq(LlmConstants::EMBEDDING_VECTOR_DIMENSIONS)
    end
  end
end
