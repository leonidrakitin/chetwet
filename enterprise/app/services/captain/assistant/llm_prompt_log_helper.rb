# Logs each LLM request payload (system + conversation up to the current assistant turn).
# Mirrors ai-agents' TracingCallbacks#format_chat_messages — messages exclude the response
# message that was just appended when +on_end_message+ fires for an assistant message.
module Captain::Assistant::LlmPromptLogHelper
  MAX_PROMPT_LOG_CHARS = 100_000

  def register_llm_prompt_logging(runner)
    return runner unless log_llm_prompts?

    runner.on_chat_created do |chat, agent_name, model, context_wrapper|
      attach_llm_prompt_logging_to_chat(chat, agent_name, model, context_wrapper)
    end
    runner
  end

  private

  def attach_llm_prompt_logging_to_chat(chat, agent_name, model, context_wrapper)
    chat.on_end_message do |message|
      log_llm_turn_if_assistant(message, chat, agent_name, model, context_wrapper)
    end
  end

  def log_llm_turn_if_assistant(message, chat, agent_name, model, context_wrapper)
    return unless assistant_llm_message?(message)

    payload = format_llm_request_payload_json(chat)
    return if payload.blank?

    Rails.logger.info(llm_prompt_log_line(agent_name, model, context_wrapper, payload))
  end

  def assistant_llm_message?(message)
    message.respond_to?(:role) && message.role == :assistant
  end

  def llm_prompt_log_line(agent_name, model, context_wrapper, payload)
    state = context_wrapper&.context&.dig(:state) || {}
    conversation = state[:conversation] || {}
    '[Captain LLM prompt] ' \
      "account_id=#{state[:account_id]} assistant_id=#{state[:assistant_id]} " \
      "conversation_id=#{conversation[:id]} agent=#{agent_name} model=#{model} " \
      "payload=#{truncate_prompt_log(payload)}"
  end

  def log_llm_prompts?
    if ENV.key?('CAPTAIN_LOG_LLM_PROMPTS')
      ActiveModel::Type::Boolean.new.cast(ENV['CAPTAIN_LOG_LLM_PROMPTS'])
    else
      Rails.env.development?
    end
  end

  def truncate_prompt_log(str)
    return str if str.length <= MAX_PROMPT_LOG_CHARS

    "#{str[0, MAX_PROMPT_LOG_CHARS]}...(truncated, #{str.length} chars total)"
  end

  def format_llm_request_payload_json(chat)
    return nil unless chat.respond_to?(:messages)

    messages = chat.messages
    return nil if messages.blank?

    request_messages = messages[0...-1]
    return nil if request_messages.empty?

    request_messages.map { |m| format_log_message(m) }.to_json
  end

  def format_log_message(msg)
    text = serialize_log_content(msg.content)
    text = append_tool_calls_to_log(msg, text)
    { role: msg.role.to_s, content: text }
  end

  def append_tool_calls_to_log(msg, text)
    return text unless msg.role == :assistant && msg.respond_to?(:tool_calls) && msg.tool_calls&.any?

    calls = msg.tool_calls.values.map { |tc| "#{tc.name}(#{serialize_log_content(tc.arguments)})" }.join(', ')
    text.empty? ? "Tool calls: #{calls}" : "#{text}\nTool calls: #{calls}"
  end

  def serialize_log_content(value)
    return serialize_multimodal_for_log(value) if multimodal_content_for_log?(value)

    value.is_a?(Hash) || value.is_a?(Array) ? value.to_json : value.to_s
  end

  def multimodal_content_for_log?(value)
    value.respond_to?(:text) && value.respond_to?(:attachments)
  end

  def serialize_multimodal_for_log(content)
    segments = []
    segments << content.text if content.respond_to?(:text) && content.text.present?
    segments << attachment_urls_segment(content) if content.respond_to?(:attachments) && content.attachments&.any?
    segments.compact.join("\n")
  end

  def attachment_urls_segment(content)
    urls = content.attachments.map { |a| a.respond_to?(:source) ? a.source.to_s : a.to_s }
    "Attachments: #{urls.join(', ')}"
  end
end
