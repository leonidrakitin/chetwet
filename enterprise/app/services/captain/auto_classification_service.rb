class Captain::AutoClassificationService
  include Integrations::LlmInstrumentation

  def initialize(conversation:, assistant: nil)
    @conversation = conversation
    @assistant = assistant || default_assistant
  end

  # Classifies conversation using GLM-5 with structured output
  # Returns classification result with department, priority, sentiment, tags, etc.
  def classify
    return nil unless @conversation && @assistant

    instrument_classification do
      perform_classification
    end
  rescue StandardError => e
    Rails.logger.error "[Captain Classification] Error: #{e.message}"
    nil
  end

  private

  def default_assistant
    Captain::Assistant.find_by(account_id: @conversation.account_id)
  end

  def perform_classification
    message = build_classification_message
    return nil if message.blank?

    response = call_llm(message)
    parse_classification_response(response)
  end

  def build_classification_message
    text_parts = []

    # Build classification context from conversation
    text_parts << "Customer message: #{@conversation.messages.last&.content.to_s[0..500]}"
    text_parts << "Conversation status: #{@conversation.status}"
    text_parts << "Conversation labels: #{@conversation.label_list.join(', ')}" if @conversation.label_list.any?
    text_parts << "Customer name: #{@conversation.contact.name}" if @conversation.contact&.name

    text_parts << "\nPlease classify this conversation with the following structure:"
    text_parts << '- department: one of [sales, support, billing, technical, general]'
    text_parts << '- priority: one of [low, medium, high, urgent]'
    text_parts << '- sentiment: one of [negative, neutral, positive]'
    text_parts << '- language: detected language code'
    text_parts << '- tags: array of categorization tags'
    text_parts << '- requires_immediate_response: boolean'
    text_parts << '- suggested_response_template: suggested FAQ or template ID'

    text_parts.join("\n")
  end

  def call_llm(message_text)
    api_key = classification_api_key
    return nil if api_key.blank?

    api_base = classification_api_base
    model = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value.presence || Llm::Config::DEFAULT_MODEL

    Llm::Config.with_api_key(api_key, api_base: api_base) do |context|
      chat = context.chat(model: model).with_temperature(0.3)
      chat.with_instructions(CLASSIFICATION_SYSTEM_PROMPT).ask(message_text)
    end
  rescue StandardError => e
    Rails.logger.error "[Captain Classification LLM] Error: #{e.message}"
    nil
  end

  def classification_api_key
    account = @conversation.account
    hook = account.hooks.find_by(app_id: 'openai', status: 'enabled')
    hook&.settings&.dig('api_key') || InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
  end

  def classification_api_base
    endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value
    return nil if endpoint.blank?

    base = endpoint.to_s.strip.chomp('/')
    %r{/v\d+/?$}.match?(base) ? base : "#{base}/v1"
  end

  def parse_classification_response(response)
    return nil if response.blank?

    # Response is already parsed into structured format by RubyLLM with schema
    result = response.is_a?(Hash) ? response : JSON.parse(response.to_s)
    result.with_indifferent_access
  rescue StandardError
    nil
  end

  def instrument_classification
    return yield unless ChatwootApp.otel_enabled?

    tracer.in_span('llm.conversation.classification') do |span|
      span.set_attribute('gen_ai.provider', 'zai')
      span.set_attribute('gen_ai.model', InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value || 'glm-5')
      span.set_attribute('gen_ai.operation.name', 'classification')
      span.set_attribute(format(ATTR_LANGFUSE_METADATA, 'conversation_id'), @conversation.id.to_s)
      yield
    end
  end

  CLASSIFICATION_SYSTEM_PROMPT = <<~PROMPT
    You are a customer service classification assistant. Analyze the provided conversation and classify it using the specified schema.

    Provide classification that helps route and prioritize customer service tickets effectively.

    Be precise and consistent in your classifications.
  PROMPT
end
