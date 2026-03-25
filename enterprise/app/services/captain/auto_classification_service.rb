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
    text_parts << "Customer name: #{@conversation.contact.name}" if @conversation.contact
    text_parts << "Customer email: #{@conversation.contact.email}" if @conversation.contact&.email

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
    config = Captain::Llm::Config.new(@assistant.account_id)
    model = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value || LlmConstants::DEFAULT_MODEL

    Llm::Config.with_api_key(config.api_key) do
      chat = RubyLLM::Chat.with_model(model)
      chat = chat.with_schema(Captain::ClassificationSchema)
      chat = chat.with_instructions(CLASSIFICATION_SYSTEM_PROMPT)
      chat.prompt(message_text)
    end
  rescue StandardError => e
    Rails.logger.error "[Captain Classification LLM] Error: #{e.message}"
    nil
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
