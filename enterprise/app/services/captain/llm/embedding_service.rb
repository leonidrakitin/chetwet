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

    api_base, api_key_set = embedding_config_for_log(determine_provider(model))
    Rails.logger.info "[1EmbeddingService] model=#{model.inspect} provider=#{determine_provider(model)} api_base=#{api_base.inspect} api_key=#{api_key_set ? '[SET]' : '[NOT SET]'}" # TODO: remove temporary log

    instrument_embedding_call(instrumentation_params(content, model)) do
      RubyLLM.embed(content, model: model, provider: :openai, assume_model_exists: true).vectors
    end
  rescue RubyLLM::Error => e
    Rails.logger.error "Embedding API Error: #{e.message}"
    raise EmbeddingsError, "Failed to create an embedding: #{e.message}"
  end

  private

  def embedding_config_for_log(provider)
    cfg = Llm::Config::PROVIDER_CONFIGS[provider]
    return [nil, false] unless cfg

    api_base = InstallationConfig.find_by(name: cfg[:endpoint_name])&.value.presence || cfg[:default_endpoint]
    api_key_set = InstallationConfig.find_by(name: cfg[:key_name])&.value.present?
    [api_base&.chomp('/'), api_key_set]
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
