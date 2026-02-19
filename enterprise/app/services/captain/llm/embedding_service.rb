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

    provider = determine_provider(model)
    api_base = ruby_llm_base_for(provider)
    api_key_set = ruby_llm_key_set_for(provider)
    Rails.logger.info "[EmbeddingService] model=#{model.inspect} provider=#{provider} api_base=#{api_base.inspect} api_key=#{api_key_set ? '[SET]' : '[NOT SET]'}" # TODO: remove temporary log

    instrument_embedding_call(instrumentation_params(content, model)) do
      RubyLLM.embed(content, model: model, provider: determine_provider(model).to_sym, assume_model_exists: true).vectors
    end
  rescue RubyLLM::Error => e
    Rails.logger.error "Embedding API Error: #{e.message}"
    raise EmbeddingsError, "Failed to create an embedding: #{e.message}"
  end

  private

  def ruby_llm_base_for(provider)
    attr = :"#{provider}_api_base"
    RubyLLM.configuration.respond_to?(attr) ? RubyLLM.configuration.public_send(attr) : nil
  end

  def ruby_llm_key_set_for(provider)
    attr = :"#{provider}_api_key"
    return false unless RubyLLM.configuration.respond_to?(attr)

    RubyLLM.configuration.public_send(attr).present?
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
