# Summarizes long conversation history for the orchestrator to avoid lost-in-the-middle.
# Returns structured context (summary, intent, active_scenarios, key_facts) + recent messages.
# Caches by conversation_id + hash(last 5 messages), TTL 10 min.
class Captain::ConversationSummarizerService
  THRESHOLD = 10
  RECENT_COUNT = 8
  CACHE_TTL_SECONDS = 600
  CACHE_KEY_PREFIX = 'captain:conv_summary'.freeze

  def initialize(conversation:, message_history:)
    @conversation = conversation
    @message_history = message_history
  end

  # Returns nil if history is short; otherwise { summary:, current_intent:, active_scenarios:, key_facts:, recent_messages: }.
  def call
    return nil if @message_history.size < THRESHOLD

    cache_key = build_cache_key
    cached = Redis::Alfred.get(cache_key)
    return parse_cached(cached) if cached.present?

    build_and_cache(cache_key)
  end

  private

  def build_cache_key
    last_five = @message_history.last(5).map { |m| message_signature(m) }
    hash_suffix = Digest::SHA256.hexdigest(last_five.to_json)
    "#{CACHE_KEY_PREFIX}:#{@conversation.id}:#{hash_suffix}"
  end

  def message_signature(msg)
    { role: msg[:role], content: content_to_string(msg[:content]) }
  end

  def content_to_string(content)
    return content.to_s if content.is_a?(String)
    return content[:response] || content['response'] || content.to_s if content.is_a?(Hash)
    return content.filter_map { |part| part[:text] || part['text'] }.join(' ') if content.is_a?(Array)

    content.to_s
  end

  def parse_cached(json_str)
    data = JSON.parse(json_str)
    {
      summary: data['summary'].to_s,
      current_intent: data['current_intent'].to_s,
      active_scenarios: data['active_scenarios'] || [],
      key_facts: data['key_facts'] || [],
      recent_messages: (data['recent_messages'] || []).map(&:symbolize_keys)
    }
  rescue JSON::ParserError
    nil
  end

  def build_and_cache(cache_key)
    old_messages = @message_history[0..-(RECENT_COUNT + 1)]
    recent_messages = @message_history.last(RECENT_COUNT)
    conversation_text = old_messages.map { |m| "#{m[:role]}: #{content_to_string(m[:content])}" }.join("\n")

    prompt = summarizer_prompt(conversation_text)
    response = llm_ask(prompt)
    parsed = parse_llm_response(response)

    return nil unless parsed

    recent_serializable = recent_messages.map do |m|
      { role: m[:role], content: content_to_string(m[:content]), agent_name: m[:agent_name] }.compact
    end
    result = {
      summary: parsed['summary'].to_s,
      current_intent: parsed['current_intent'].to_s,
      active_scenarios: Array(parsed['active_scenarios']),
      key_facts: Array(parsed['key_facts']),
      recent_messages: recent_messages
    }
    cache_value = result.merge(recent_messages: recent_serializable).transform_keys(&:to_s).to_json
    Redis::Alfred.setex(cache_key, cache_value, CACHE_TTL_SECONDS)
    result
  end

  def summarizer_prompt(conversation_text)
    <<~PROMPT
      Summarize this conversation for an AI orchestrator. Reply with a single JSON object (no markdown) with keys:
      - "summary": 1-2 short paragraphs of what was discussed.
      - "current_intent": the user's current goal or question in one sentence.
      - "active_scenarios": array of scenario keys that might apply (e.g. ["sales_agent", "support_agent"]), or [].
      - "key_facts": array of important facts (pricing discussed, names, decisions), or [].

      Conversation:
      #{conversation_text}
    PROMPT
  end

  def llm_ask(user_content)
    api_key = conversation_api_key
    if api_key.blank?
      Rails.logger.debug '[Captain] ConversationSummarizerService: no API key (account hook or CAPTAIN_OPEN_AI_API_KEY), skipping summary'
      return nil
    end

    api_base = conversation_api_base
    Llm::Config.with_api_key(api_key, api_base: api_base) do |context|
      chat = context.chat(model: summarizer_model).with_temperature(0.3)
      chat.with_instructions(
        'You are a summarizer. Reply only with valid JSON matching the requested keys. No markdown, no explanation.'
      ).ask(user_content)
    end
  rescue StandardError => e
    if auth_error?(e)
      Rails.logger.info "[Captain] ConversationSummarizerService: LLM auth failed (#{e.message}), using full history"
    else
      Rails.logger.error "[Captain] ConversationSummarizerService LLM error: #{e.message}"
    end
    nil
  end

  def conversation_api_key
    account = @conversation.account
    hook = account.hooks.find_by(app_id: 'openai', status: 'enabled')
    hook&.settings&.dig('api_key') || InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
  end

  def conversation_api_base
    Llm::Config.captain_openai_api_base
  end

  def summarizer_model
    InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value.presence || Llm::Config::DEFAULT_MODEL
  end

  def parse_llm_response(response)
    return nil if response.blank?

    content = response.respond_to?(:content) ? response.content : response.to_s
    JSON.parse(content.strip)
  rescue JSON::ParserError
    nil
  end

  def auth_error?(e)
    msg = e.message.to_s.downcase
    msg.include?('missing authentication') || msg.include?('invalid api key') || msg.include?('unauthorized') ||
      msg.include?('authentication header')
  end
end
