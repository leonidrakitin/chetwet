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
      api_key, api_base = Llm::Config.embedding_openai_credentials
      Llm::Config.with_api_key(api_key, api_base: api_base) do
        RubyLLM.embed(content, model: model).vectors || []
      end
    end
  rescue StandardError => e
    log_embedding_failure(e, content, model)
    raise EmbeddingsError, "Failed to create an embedding: #{e.message}"
  end

  private

  def log_embedding_failure(error, content, model)
    Rails.logger.error(
      "[Captain][EmbeddingService] #{error.class}: #{error.message} " \
      "account_id=#{@account_id.inspect} model=#{model.inspect} " \
      "content_bytes=#{content.to_s.bytesize} content_preview=#{content.to_s.truncate(200).inspect}"
    )
    Rails.logger.error(error.full_message) if error.respond_to?(:full_message)
    Rails.logger.error(error.backtrace&.first(15)&.join("\n")) if error.backtrace
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
