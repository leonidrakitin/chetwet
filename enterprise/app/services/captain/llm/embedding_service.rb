class Captain::Llm::EmbeddingService
  include Integrations::LlmInstrumentation

  class EmbeddingsError < StandardError; end

  def initialize(account_id: nil)
    Llm::Config.initialize!
    @account_id = account_id
  end

  def self.embedding_model
    LlmConstants::DEFAULT_EMBEDDING_MODEL
  end

  def get_embedding(content, model: LlmConstants::DEFAULT_EMBEDDING_MODEL)
    return [] if content.blank?

    instrument_embedding_call(instrumentation_params(content, model)) do
      RubyLLM.embed(content, model: model, provider: determine_provider(model).to_sym, assume_model_exists: true).vectors
    end
  rescue RubyLLM::Error => e
    Rails.logger.error "Embedding API Error: #{e.message}"
    raise EmbeddingsError, "Failed to create an embedding: #{e.message}"
  end

  private

  def instrumentation_params(content, model)
    {
      span_name: 'llm.captain.embedding',
      model: model,
      input: content,
      feature_name: 'embedding',
      account_id: @account_id
    }
  end
end
