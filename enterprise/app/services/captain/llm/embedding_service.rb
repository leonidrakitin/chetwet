class Captain::Llm::EmbeddingService
  include Integrations::LlmInstrumentation

  class EmbeddingsError < StandardError; end

  def initialize(account_id: nil)
    Llm::Config.initialize!
    @account_id = account_id
    @embedding_model = InstallationConfig.find_by(name: 'CAPTAIN_EMBEDDING_MODEL')&.value.presence || LlmConstants::DEFAULT_EMBEDDING_MODEL
  end

  def self.embedding_model
    InstallationConfig.find_by(name: 'CAPTAIN_EMBEDDING_MODEL')&.value.presence || LlmConstants::DEFAULT_EMBEDDING_MODEL
  end

  def get_embedding(content, model: @embedding_model)
    return [] if content.blank?

    instrument_embedding_call(instrumentation_params(content, model)) do
      if embedding_api_key.present? && embedding_api_base.present?
        Llm::Config.with_api_key(embedding_api_key, api_base: embedding_api_base) do
          RubyLLM.embed(content, model: model, provider: :openai, assume_model_exists: true).vectors
        end
      else
        RubyLLM.embed(content, model: model).vectors
      end
    end
  rescue RubyLLM::Error => e
    Rails.logger.error "Embedding API Error: #{e.message}"
    raise EmbeddingsError, "Failed to create an embedding: #{e.message}"
  end

  private

  def embedding_api_key
    @embedding_api_key ||= InstallationConfig.find_by(name: 'CAPTAIN_EMBEDDING_API_KEY')&.value
  end

  def embedding_api_base
    return @embedding_api_base if defined?(@embedding_api_base)

    endpoint = InstallationConfig.find_by(name: 'CAPTAIN_EMBEDDING_ENDPOINT')&.value.presence
    @embedding_api_base = endpoint.present? ? "#{endpoint.chomp('/')}/v1" : nil
  end

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
