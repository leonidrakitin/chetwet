require 'rails_helper'

RSpec.describe RubyLLMOpenAIEmbeddingPatch do
  subject(:provider) do
    Class.new do
      prepend RubyLLMOpenAIEmbeddingPatch
    end.new
  end

  describe '#parse_embedding_response' do
    it 'raises RubyLLM::Error with the upstream error message for hash bodies' do
      response = Struct.new(:body).new({
                                         'error' => { 'message' => 'No successful provider responses.', 'code' => 404 }
                                       })

      expect do
        provider.send(:parse_embedding_response, response, model: 'text-embedding-ada-002', text: 'отмена заказа')
      end.to raise_error(
        RubyLLM::Error,
        /Embedding API error: No successful provider responses\./
      )
    end

    it 'raises RubyLLM::Error instead of NoMethodError for raw string bodies' do
      response = '{"error":{"message":"No successful provider responses.","code":404}}'

      expect do
        provider.send(:parse_embedding_response, response, model: 'text-embedding-ada-002', text: 'отмена заказа')
      end.to raise_error(
        RubyLLM::Error,
        /Embedding API error: No successful provider responses\./
      )
    end
  end
end
