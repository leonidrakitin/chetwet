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

    @trace_recorder.record(:run_completed, { response: truncate_for_trace(@response&.dig('response')) })
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
      callbacks: trace_runner_callbacks
    ).generate_response(message_history: message_history)
    process_response
  end

  def trace_runner_callbacks
    return {} unless @trace_recorder.enabled?

    recorder = @trace_recorder
    {
      on_tool_start: lambda { |tool_name, args, _ctx|
        recorder.record(:tool_start, { tool: tool_name, args: args })
      },
      on_tool_complete: lambda { |tool_name, result, _ctx|
        recorder.record(:tool_complete, { tool: tool_name, result: truncate_for_trace(result) })
      },
      on_agent_handoff: lambda { |from_agent, to_agent, reason, _ctx|
        recorder.record(:agent_handoff, { from: from_agent, to: to_agent, reason: reason })
      }
    }
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

  def process_response
    return unless conversation_pending?
    return if pending_approval_request_exists?
    return if @response['response'].blank?

    if handoff_requested?
      @trace_recorder.record(:handoff, { reasoning: truncate_for_trace(@response['reasoning']) })
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
