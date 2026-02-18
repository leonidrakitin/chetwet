module Captain::ChatHelper
  include Integrations::LlmInstrumentation
  include Captain::ChatResponseHelper
  include Captain::ChatGenerationRecorder

  PROVIDER_CONFIGS = Llm::Config::PROVIDER_CONFIGS
  DEFAULT_PROVIDER = 'openai'

  def request_chat_completion
    log_chat_completion_request

    Llm::Config.with_api_key(resolve_captain_api_key, api_base: resolve_captain_api_base) do |context|
      chat = build_chat(context)
      add_messages_to_chat(chat)
      with_agent_session do
        last_content = conversation_messages.last[:content]
        text, attachments = Captain::OpenAiMessageBuilderService.extract_text_and_attachments(last_content)

        response = attachments.any? ? chat.ask(text, with: attachments) : chat.ask(text)
        build_response(response)
      end
    end
  rescue StandardError => e
    Rails.logger.error "#{self.class.name} Assistant: #{@assistant.id}, Error in chat completion: #{e}"
    raise e
  end

  private

  def provider_for(model_name)
    Llm::Models.models.dig(model_name, 'provider') || DEFAULT_PROVIDER
  end

  def provider_config_for(model_name)
    provider = provider_for(model_name)
    PROVIDER_CONFIGS[provider] || PROVIDER_CONFIGS[DEFAULT_PROVIDER]
  end

  # For the default provider (openai), checks for an account-level hook override first.
  # For other providers, reads from InstallationConfig directly.
  def resolve_captain_api_key
    config = provider_config_for(@model)
    provider = provider_for(@model)

    if provider != DEFAULT_PROVIDER
      key = fetch_config(config[:key_name])
      return key if key.present?
    end

    captain_api_key
  end

  def resolve_captain_api_base
    config = provider_config_for(@model)
    provider = provider_for(@model)

    if provider != DEFAULT_PROVIDER
      key = fetch_config(config[:key_name])
      return build_api_base(config) if key.present?
    end

    captain_api_base
  end

  def captain_api_key
    @captain_api_key ||= openai_hook&.settings&.dig('api_key') || fetch_config('CAPTAIN_OPEN_AI_API_KEY')
  end

  def captain_api_base
    config = PROVIDER_CONFIGS[DEFAULT_PROVIDER]
    build_api_base(config)
  end

  def build_api_base(config)
    endpoint = fetch_config(config[:endpoint_name]).presence || config[:default_endpoint]
    endpoint = endpoint.chomp('/')
    "#{endpoint}/v1"
  end

  def openai_hook
    @openai_hook ||= resolved_account&.hooks&.find_by(app_id: 'openai', status: 'enabled')
  end

  def resolved_account
    @account || @assistant&.account
  end

  def build_chat(context)
    llm_chat = context.chat(model: @model, provider: :openai, assume_model_exists: true).with_temperature(temperature)
    unless non_default_provider?(@model)
      llm_chat = llm_chat.with_params(response_format: { type: 'json_object' })
    end
    llm_chat = setup_tools(llm_chat)
    llm_chat = setup_system_instructions(llm_chat)
    setup_event_handlers(llm_chat)
  end

  def non_default_provider?(model_name)
    provider_for(model_name) != DEFAULT_PROVIDER
  end

  def setup_tools(llm_chat)
    @tools&.each do |tool|
      llm_chat = llm_chat.with_tool(tool)
    end
    llm_chat
  end

  def setup_system_instructions(chat)
    system_messages = @messages.select { |m| m[:role] == 'system' || m[:role] == :system }
    combined_instructions = system_messages.pluck(:content).join("\n\n")
    chat.with_instructions(combined_instructions)
  end

  def setup_event_handlers(chat)
    # NOTE: We only use on_end_message to record the generation with token counts.
    # RubyLLM callbacks fire after chunks arrive, not around the API call, so
    # span timing won't reflect actual API latency. But Langfuse calculates costs
    # from model + token counts, so this is sufficient for cost tracking.
    chat.on_end_message { |message| record_llm_generation(chat, message) }
    chat.on_tool_call { |tool_call| handle_tool_call(tool_call) }
    chat.on_tool_result { |result| handle_tool_result(result) }

    chat
  end

  def handle_tool_call(tool_call)
    persist_thinking_message(tool_call)
    start_tool_span(tool_call)
    @pending_tool_calls ||= []
    @pending_tool_calls.push(tool_call)
  end

  def handle_tool_result(result)
    end_tool_span(result)
    persist_tool_completion
  end

  def add_messages_to_chat(chat)
    conversation_messages[0...-1].each do |msg|
      text, attachments = Captain::OpenAiMessageBuilderService.extract_text_and_attachments(msg[:content])
      content = attachments.any? ? RubyLLM::Content.new(text, attachments) : text
      chat.add_message(role: msg[:role].to_sym, content: content)
    end
  end

  def instrumentation_params(chat = nil)
    {
      span_name: "llm.captain.#{feature_name}",
      account_id: resolved_account_id,
      conversation_id: @conversation_id,
      feature_name: feature_name,
      model: @model,
      messages: chat ? chat.messages.map { |m| { role: m.role.to_s, content: m.content.to_s } } : @messages,
      temperature: temperature,
      metadata: {
        assistant_id: @assistant&.id
      }
    }
  end

  def conversation_messages
    @messages.reject { |m| m[:role] == 'system' || m[:role] == :system }
  end

  def temperature
    @assistant&.config&.[]('temperature').to_f || 1
  end

  def resolved_account_id
    @account&.id || @assistant&.account_id
  end

  # Ensures all LLM calls and tool executions within an agentic loop
  # are grouped under a single trace/session in Langfuse.
  #
  # Without this guard, each recursive call to request_chat_completion
  # (triggered by tool calls) would create a separate trace instead of
  # nesting within the existing session span.
  def with_agent_session(&)
    already_active = @agent_session_active
    return yield if already_active

    @agent_session_active = true
    instrument_agent_session(instrumentation_params, &)
  ensure
    @agent_session_active = false unless already_active
  end

  # Must be implemented by including class to identify the feature for instrumentation.
  # Used for Langfuse tagging and span naming.
  def feature_name
    raise NotImplementedError, "#{self.class.name} must implement #feature_name"
  end

  def log_chat_completion_request
    Rails.logger.info(
      "#{self.class.name} Assistant: #{@assistant.id}, Requesting chat completion
      for messages #{@messages} with #{@tools&.length || 0} tools
      "
    )
  end

  def fetch_config(name)
    @config_cache ||= {}
    return @config_cache[name] if @config_cache.key?(name)

    @config_cache[name] = InstallationConfig.find_by(name: name)&.value
  end
end
