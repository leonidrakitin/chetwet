class Captain::Conversation::ResponseBuilderJob < ApplicationJob # rubocop:disable Metrics/ClassLength
  MAX_MESSAGE_LENGTH = 10_000
  retry_on ActiveStorage::FileNotFoundError, attempts: 3, wait: 2.seconds
  retry_on Faraday::BadRequestError, attempts: 3, wait: 2.seconds

  def perform(conversation, assistant) # rubocop:disable Metrics/MethodLength
    @conversation = conversation
    @inbox = conversation.inbox
    @assistant = assistant
    @trace_recorder = Captain::Trace::Recorder.new(conversation: conversation, assistant: assistant, source: 'response_builder_job')
    @created_message = nil

    return unless conversation_pending?

    Current.executed_by = @assistant

    @trace_recorder.record(:run_started, { v2: captain_v2_enabled? })

    if captain_v2_enabled?
      generate_response_with_v2
    else
      generate_and_process_response
    end

    @trace_recorder.record(:run_completed, {
      response: truncate_for_trace(@response&.dig('response')),
      duration_ms: @trace_recorder.run_duration_ms
    }.compact)
    @trace_recorder.flush_to(source_message: @created_message)
  rescue ActiveStorage::FileNotFoundError, Faraday::BadRequestError => e
    handle_error(e)
    flush_trace_on_error(e)
    raise e
  rescue StandardError => e
    handle_error(e)
    flush_trace_on_error(e)
  ensure
    Current.executed_by = nil
  end

  private

  delegate :account, :inbox, to: :@conversation

  def generate_and_process_response
    @response = Captain::Llm::AssistantChatService.new(assistant: @assistant, conversation: @conversation).generate_response(
      message_history: collect_previous_messages
    )
    process_response
  end

  def generate_response_with_v2
    message_history = collect_previous_messages
    detect_and_persist_language(message_history)
    message_history = build_message_history_for_v2(message_history)
    @response = Captain::Assistant::AgentRunnerService.new(
      assistant: @assistant,
      conversation: @conversation,
      callbacks: trace_runner_callbacks,
      trace_recorder: @trace_recorder
    ).generate_response(message_history: message_history)
    process_response
  end

  def trace_runner_callbacks # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
    return {} unless @trace_recorder.enabled?

    recorder = @trace_recorder
    @tool_correlations = {}
    {
      on_tool_start: lambda { |tool_name, args, _ctx|
        correlation_id = recorder.new_correlation_id
        @tool_correlations[tool_name.to_s] = { id: correlation_id, started_at: Time.current }
        recorder.record(:tool_start, { tool: tool_name, args: args, correlation_id: correlation_id })
      },
      on_tool_complete: lambda { |tool_name, result, ctx|
        meta = @tool_correlations.delete(tool_name.to_s) || {}
        duration_ms = meta[:started_at] ? ((Time.current - meta[:started_at]) * 1000).round : nil
        recorder.record(:tool_complete, {
          tool: tool_name,
          result: truncate_for_trace(result),
          correlation_id: meta[:id],
          duration_ms: duration_ms
        }.compact)
        record_tool_decision_events(recorder, tool_name, result, meta[:id], ctx)
      },
      on_agent_handoff: lambda { |from_agent, to_agent, reason, _ctx|
        recorder.record(:agent_handoff, { from: from_agent, to: to_agent, reason: reason })
      },
      on_chat_created: lambda { |chat, agent_name, model, context_wrapper|
        record_llm_request_event(recorder, agent_name, model, context_wrapper)
        attach_llm_response_listener(chat, recorder, agent_name, model)
      }
    }
  end

  def record_llm_request_event(recorder, agent_name, model, context_wrapper)
    state = context_wrapper&.context&.dig(:state) || {}
    payload = {
      agent: agent_name.to_s,
      model: model.to_s,
      detected_language: state[:detected_language],
      tools_history: state.dig(:orchestration, :tool_history),
      conversation_length: context_wrapper&.context&.dig(:conversation_length),
      autonomy_retry_count: context_wrapper&.context&.dig(:autonomy_retry_count)
    }.compact
    recorder.start_timer("llm:#{agent_name}")
    recorder.record(:llm_request, payload)
  rescue StandardError => e
    Rails.logger.warn("[Captain::Trace] llm_request capture failed: #{e.message}")
  end

  def attach_llm_response_listener(chat, recorder, agent_name, model)
    return unless chat.respond_to?(:on_end_message)

    chat.on_end_message do |message|
      next unless message.respond_to?(:role) && message.role == :assistant

      duration_ms = recorder.stop_timer("llm:#{agent_name}")
      tool_calls = extract_tool_call_summary(message)
      record_prompt_snapshot(recorder, chat, agent_name, model)
      recorder.record(:llm_response, {
        agent: agent_name.to_s,
        model: model.to_s,
        duration_ms: duration_ms,
        content_summary: truncate_for_trace(message.respond_to?(:content) ? message.content.to_s : ''),
        tool_calls: tool_calls
      }.compact)
    rescue StandardError => e
      Rails.logger.warn("[Captain::Trace] llm_response capture failed: #{e.message}")
    end
  end

  PROMPT_SNAPSHOT_MAX_MESSAGES = 30
  PROMPT_SNAPSHOT_PER_MESSAGE_CHARS = 1_500
  PROMPT_SNAPSHOT_SYSTEM_CHARS = 4_000
  PROMPT_SNAPSHOT_TOOL_DESC_CHARS = 240

  def record_prompt_snapshot(recorder, chat, agent_name, model)
    return unless chat.respond_to?(:messages)

    prompt_messages = Array(chat.messages)[0...-1]
    return if prompt_messages.blank?

    serialized = prompt_messages.map { |m| serialize_prompt_message(m) }
    system_messages = serialized.select { |m| m[:role] == 'system' }
    other_messages = serialized.reject { |m| m[:role] == 'system' }

    recorder.record(:prompt_snapshot, {
      agent: agent_name.to_s,
      model: model.to_s,
      system_prompt: build_prompt_system_summary(system_messages),
      messages: build_prompt_messages_payload(other_messages),
      message_count: serialized.size,
      tool_instructions: build_prompt_tool_instructions(chat)
    }.compact)
  rescue StandardError => e
    Rails.logger.warn("[Captain::Trace] prompt_snapshot capture failed: #{e.message}")
  end

  def serialize_prompt_message(message)
    role = message.respond_to?(:role) ? message.role.to_s : 'unknown'
    content = serialize_prompt_message_content(message)
    out = { role: role, content: content }
    if message.respond_to?(:tool_calls) && message.tool_calls.is_a?(Hash) && message.tool_calls.any?
      out[:tool_calls] = message.tool_calls.values.first(5).map do |tc|
        {
          name: tc.respond_to?(:name) ? tc.name.to_s : nil,
          arguments: tc.respond_to?(:arguments) ? tc.arguments.to_s.truncate(PROMPT_SNAPSHOT_PER_MESSAGE_CHARS) : nil
        }.compact
      end
    end
    out
  end

  def serialize_prompt_message_content(message)
    return '' unless message.respond_to?(:content)

    raw = message.content
    str = if raw.respond_to?(:text) && raw.respond_to?(:attachments)
            text = raw.text.to_s
            urls = Array(raw.attachments).map { |a| a.respond_to?(:source) ? a.source.to_s : a.to_s }
            urls.any? ? "#{text}\n[attachments: #{urls.join(', ')}]" : text
          elsif raw.is_a?(Hash) || raw.is_a?(Array)
            raw.to_json
          else
            raw.to_s
          end
    str.to_s.truncate(PROMPT_SNAPSHOT_PER_MESSAGE_CHARS)
  end

  def build_prompt_system_summary(system_messages)
    return nil if system_messages.blank?

    combined = system_messages.map { |m| m[:content].to_s }.join("\n---\n")
    combined.truncate(PROMPT_SNAPSHOT_SYSTEM_CHARS)
  end

  def build_prompt_messages_payload(messages)
    messages.last(PROMPT_SNAPSHOT_MAX_MESSAGES)
  end

  PROMPT_SNAPSHOT_TOOL_LIMIT = 50

  def build_prompt_tool_instructions(chat)
    tools = chat.respond_to?(:tools) ? chat.tools : nil
    return nil if tools.blank?

    list = tools.respond_to?(:values) ? tools.values : Array(tools)
    list.first(PROMPT_SNAPSHOT_TOOL_LIMIT).map do |t|
      raw_name = t.respond_to?(:name) ? t.name.to_s : nil
      {
        name: raw_name,
        display_name: normalize_prompt_tool_name(raw_name),
        description: (t.respond_to?(:description) ? t.description.to_s : '').truncate(PROMPT_SNAPSHOT_TOOL_DESC_CHARS)
      }.compact
    end
  end

  def normalize_prompt_tool_name(raw_name)
    return nil if raw_name.blank?

    raw_name.to_s.delete_prefix('captain--tools--').sub(/\Acaptain::tools::/i, '')
  end

  def extract_tool_call_summary(message)
    return nil unless message.respond_to?(:tool_calls) && message.tool_calls.is_a?(Hash)
    return nil if message.tool_calls.blank?

    message.tool_calls.values.first(5).map do |tc|
      {
        name: tc.respond_to?(:name) ? tc.name.to_s : nil,
        arguments: tc.respond_to?(:arguments) ? truncate_for_trace(tc.arguments) : nil
      }.compact
    end
  end

  def record_tool_decision_events(recorder, tool_name, result, correlation_id, _ctx)
    case tool_name.to_s
    when /faq_lookup/
      record_faq_lookup_decision(recorder, result, correlation_id)
    when /search_documentation/
      record_search_documentation_hit(recorder, result, correlation_id)
    when /schedule_follow_up/
      record_schedule_follow_up_decision(recorder, result, correlation_id)
    when /create_notification_template/
      record_notification_template_decision(recorder, result, correlation_id)
    when /handoff|escalate_to_human/
      record_handoff_tool_decision(recorder, result, correlation_id, ctx)
    end
  rescue StandardError => e
    Rails.logger.warn("[Captain::Trace] tool decision capture failed: #{e.message}")
  end

  def record_search_documentation_hit(recorder, result, correlation_id)
    text = result.to_s
    found = !text.start_with?('No FAQs found')
    recorder.record_knowledge_hit(
      source: 'search_documentation',
      reference: nil,
      snippet: text,
      extra: { found: found, correlation_id: correlation_id }
    )
  end

  def record_faq_lookup_decision(recorder, result, correlation_id) # rubocop:disable Metrics/MethodLength
    return unless result.is_a?(Hash)

    data = result.with_indifferent_access
    policy = data['policy'].to_s
    confidence = data['confidence']
    sources = Array(data['sources']).first(5).map { |s| s.is_a?(Hash) ? s.slice('label', 'title', 'url').compact : s }
    recorder.record_knowledge_hit(
      source: 'faq_lookup',
      query: data['query'],
      score: confidence,
      reference: sources,
      extra: { policy: policy }
    )
    selected = policy == 'answer'
    recorder.record_decision(
      selected ? :decision_selected : :decision_rejected,
      domain: 'tool_choice', name: 'faq_lookup',
      selected: selected,
      reasoning_summary: "FAQ policy=#{policy.presence || 'none'} confidence=#{confidence}",
      inputs: { query: data['query'], confidence: confidence, policy: policy },
      correlation_id: correlation_id
    )
  end

  def record_schedule_follow_up_decision(recorder, result, correlation_id) # rubocop:disable Metrics/MethodLength
    return unless result.is_a?(Hash)

    data = result.with_indifferent_access
    if data['status'].to_s == 'scheduled'
      scheduled_for = data['scheduled_for']
      delay_seconds = data['delay_minutes'] ? data['delay_minutes'].to_i * 60 : nil
      recorder.record_decision(
        :decision_selected,
        domain: 'delayed_send', name: 'schedule_follow_up',
        selected: true,
        reasoning_summary: 'Scheduled outbound follow-up message',
        scheduled_for: scheduled_for,
        delay_seconds: delay_seconds,
        inputs: { delivery_id: data['delivery_id'] },
        correlation_id: correlation_id
      )
    else
      recorder.record_decision(
        :decision_rejected,
        domain: 'delayed_send', name: 'schedule_follow_up',
        selected: false,
        reasoning_summary: data['error'].to_s.presence || 'Schedule follow-up rejected',
        correlation_id: correlation_id
      )
    end
  end

  def record_notification_template_decision(recorder, result, correlation_id)
    summary = result.to_s
    selected = summary.include?('created successfully')
    template_id = summary[/ID:\s*(\d+)/, 1]
    template_name = summary[/Name:\s*([^,]+)/, 1]
    recorder.record_decision(
      selected ? :decision_selected : :decision_rejected,
      domain: 'notification_template', name: 'create_notification_template',
      selected: selected,
      reasoning_summary: summary.to_s.truncate(400),
      template_id: template_id,
      template_name: template_name&.strip,
      correlation_id: correlation_id
    )
  end

  def record_handoff_tool_decision(recorder, result, correlation_id, ctx)
    summary = result.is_a?(Hash) ? result.to_json : result.to_s
    proactive = extract_proactive_faq_payload(ctx)
    recorder.record_decision(
      :escalation_decision,
      domain: 'handoff', name: 'handoff_tool',
      selected: true,
      reasoning_summary: summary.to_s.truncate(400),
      inputs: proactive ? { proactive_faq: proactive } : nil,
      correlation_id: correlation_id
    )
    record_proactive_faq_knowledge_hit(recorder, proactive, correlation_id) if proactive
  end

  def extract_proactive_faq_payload(ctx)
    payload = ctx&.context&.dig(:state, :orchestration, :handoff_proactive_faq) ||
              ctx&.context&.dig(:state, :orchestration, 'handoff_proactive_faq')
    return nil unless payload.is_a?(Hash)

    payload.deep_stringify_keys
  end

  def record_proactive_faq_knowledge_hit(recorder, proactive, correlation_id)
    recorder.record_knowledge_hit(
      source: 'faq_lookup_proactive',
      query: proactive['query'],
      reference: Array(proactive['options']),
      extra: { trigger: 'handoff_proactive', found_count: proactive['found_count'], correlation_id: correlation_id }
    )
  end

  def build_message_history_for_v2(messages)
    messages = deduplicate_consecutive_assistant_messages(messages)
    return messages if messages.size < Captain::ConversationSummarizerService::THRESHOLD

    summarizer = Captain::ConversationSummarizerService.new(conversation: @conversation, message_history: messages)
    summary_result = summarizer.call
    return messages unless summary_result

    summary_system_msg = format_summary_context_for_orchestrator(summary_result)
    [{ role: :system, content: summary_system_msg }] + summary_result[:recent_messages]
  end

  def deduplicate_consecutive_assistant_messages(messages)
    deduped = []

    messages.each do |message|
      previous = deduped.last
      if previous.present? &&
         previous[:role].to_s == 'assistant' &&
         message[:role].to_s == 'assistant' &&
         previous[:content] == message[:content] &&
         previous[:agent_name].to_s == message[:agent_name].to_s
        next
      end

      deduped << message
    end

    deduped
  end

  def format_summary_context_for_orchestrator(summary_result)
    parts = ["Conversation summary: #{summary_result[:summary]}"]
    parts << "Current intent: #{summary_result[:current_intent]}" if summary_result[:current_intent].present?
    parts << "Active scenarios (consider handoff): #{summary_result[:active_scenarios].join(', ')}" if summary_result[:active_scenarios]&.any?
    parts << "Key facts: #{summary_result[:key_facts].join('; ')}" if summary_result[:key_facts]&.any?
    parts << "Detected language: #{summary_result[:detected_language]}" if summary_result[:detected_language].present?
    parts.join("\n")
  end

  def process_response # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
    return unless conversation_pending?
    return if pending_approval_request_exists?
    return if @response['response'].blank?

    if handoff_requested?
      @trace_recorder.record(:handoff, { reasoning: truncate_for_trace(@response['reasoning']) })
      @trace_recorder.record_decision(
        :decision_selected,
        domain: 'handoff', name: 'process_response_handoff',
        selected: true,
        reasoning_summary: truncate_for_trace(@response['reasoning'])
      )
      process_action('handoff')
    else
      ActiveRecord::Base.transaction do
        create_messages
        Rails.logger.info("[CAPTAIN][ResponseBuilderJob] Incrementing response usage for #{account.id}")
        account.increment_response_usage
      end
      @trace_recorder.record(:outgoing_message, {
                               message_id: @created_message&.id,
                               agent_name: @response['agent_name'],
                               reasoning: truncate_for_trace(@response['reasoning']),
                               content: truncate_for_trace(@response['response'])
                             })
    end
  end

  def collect_previous_messages
    @conversation
      .messages
      .where(message_type: [:incoming, :outgoing])
      .where(private: false)
      .map do |message|
      message_hash = {
        content: prepare_multimodal_message_content(message),
        role: determine_role(message)
      }

      message_hash[:agent_name] = message.additional_attributes['agent_name'] if message.additional_attributes&.dig('agent_name').present?

      message_hash
    end
  end

  def determine_role(message)
    message.message_type == 'incoming' ? 'user' : 'assistant'
  end

  def prepare_multimodal_message_content(message)
    Captain::OpenAiMessageBuilderService.new(message: message).generate_content
  end

  def handoff_requested?
    @response['response'] == 'conversation_handoff'
  end

  def process_action(action)
    case action
    when 'handoff'
      I18n.with_locale(@assistant.account.locale) do
        create_handoff_message
        @conversation.bot_handoff!
        send_out_of_office_message_if_applicable
      end
    end
  end

  def send_out_of_office_message_if_applicable
    ::MessageTemplates::Template::OutOfOffice.perform_if_applicable(@conversation)
  end

  def create_handoff_message
    create_outgoing_message(
      @assistant.config['handoff_message'].presence || I18n.t('conversations.captain.handoff')
    )
  end

  def create_messages
    validate_message_content!(@response['response'])
    create_outgoing_message(@response['response'], agent_name: @response['agent_name'])
  end

  def validate_message_content!(content)
    raise ArgumentError, 'Message content cannot be blank' if content.blank?
  end

  def create_outgoing_message(message_content, agent_name: nil)
    additional_attrs = {}
    additional_attrs[:agent_name] = agent_name if agent_name.present?

    @created_message = @conversation.messages.create!(
      message_type: :outgoing,
      account_id: account.id,
      inbox_id: inbox.id,
      sender: @assistant,
      content: message_content,
      additional_attributes: additional_attrs
    )
  end

  def handle_error(error)
    log_error(error)
    process_action('handoff') if conversation_pending?
    true
  end

  def log_error(error)
    ChatwootExceptionTracker.new(error, account: account).capture_exception
  end

  def pending_approval_request_exists?
    Captain::ApprovalRequest.exists?(conversation_id: @conversation.id, status: :pending)
  end

  def captain_v2_enabled?
    account.feature_enabled?('captain_integration_v2')
  end

  def conversation_pending?
    status = Conversation.uncached { Conversation.where(id: @conversation.id).pick(:status) }
    status == 'pending' || status == Conversation.statuses[:pending]
  end

  def detect_and_persist_language(message_history)
    last_user_msg = message_history.reverse.find { |msg| msg[:role] == 'user' }
    return if last_user_msg.blank?

    text = extract_text_from_content(last_user_msg[:content])
    return if text.blank?

    detected = Captain::Llm::DetectLanguageService.new(
      account: @assistant.account,
      message_text: text
    ).call

    runtime_state_service.update_state(detected_language: detected)
    detected
  end

  def extract_text_from_content(content) # rubocop:disable Metrics/CyclomaticComplexity
    return content.to_s if content.is_a?(String)
    return content[:response] || content['response'] || content.to_s if content.is_a?(Hash)
    return content.filter_map { |part| part[:text] || part['text'] }.join(' ') if content.is_a?(Array)

    content.to_s
  end

  def runtime_state_service
    @runtime_state_service ||= Captain::RuntimeStateService.new(@conversation)
  end

  def flush_trace_on_error(error)
    return unless @trace_recorder

    @trace_recorder.record(:error, { class: error.class.name, message: error.message.to_s.truncate(500) })
    @trace_recorder.flush_to(source_message: @created_message)
  end

  def truncate_for_trace(value)
    case value
    when nil then nil
    when String then value.truncate(2_000)
    when Hash, Array then value
    else value.to_s.truncate(2_000)
    end
  end
end
