class Captain::Tools::HandoffTool < Captain::Tools::BasePublicTool # rubocop:disable Metrics/ClassLength -- handoff + approval messaging pipeline
  description 'Escalate the conversation to the human support team. When approval mode is enabled on the assistant, ' \
              'an approval request is created so operators can review and approve a reply before it goes to the ' \
              'customer. Use this tool when the user explicitly asks for a human agent, when the issue requires ' \
              'operator judgment, or when FAQ lookup indicates operator clarification.'
  param :reason, type: 'string', desc: 'The reason why human escalation is needed (optional)', required: false
  param :customer_message, type: 'string',
                           desc: 'Public message to the customer while the operator reviews the request (optional, ' \
                                 'overrides the generated one)',
                           required: false
  param :options, type: 'array',
                  desc: 'Array of short reply options for the operator (optional, overrides generated ones). ' \
                        'A free-text option is appended automatically.',
                  required: false
  param :post_reason_as_note, type: 'boolean',
                              desc: 'If false, do not create a private note with the reason ' \
                                    '(use when you already added a note via Add Private Note)',
                              required: false

  def name
    'escalate_to_human'
  end

  def perform(tool_context, reason: nil, customer_message: nil, options: nil, post_reason_as_note: true)
    conversation = find_conversation(tool_context.state)
    return 'Conversation not found' unless conversation

    log_tool_usage('tool_human_escalation', {
                     conversation_id: conversation.id,
                     reason: reason || 'Agent requested human escalation'
                   })

    trigger_handoff(conversation, reason, post_reason_as_note)
    run_approval_pipeline(conversation, reason, tool_context, customer_message, options) if approval_enabled?

    "Conversation escalated to human support team#{" (Reason: #{reason})" if reason}"
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
    'Failed to escalate conversation to human support'
  end

  private

  def approval_enabled?
    value = @assistant.config['handoff_approval_enabled']
    value.nil? || ActiveModel::Type::Boolean.new.cast(value)
  end

  def trigger_handoff(conversation, reason, post_reason_as_note)
    if post_reason_as_note && reason.present?
      conversation.messages.create!(
        message_type: :outgoing,
        private: true,
        sender: @assistant,
        account: conversation.account,
        inbox: conversation.inbox,
        content: reason
      )
    end

    conversation.bot_handoff!
    send_out_of_office_message_if_applicable(conversation)
  end

  def run_approval_pipeline(conversation, reason, tool_context, override_customer_message, override_options)
    conversation.reload
    faq_snippets = collect_faq_snippets(tool_context)
    generated = generate_via_llm(conversation, reason, faq_snippets)
    final_options = pick_options(override_options, generated[:options], faq_snippets)
    final_customer_message = override_customer_message.presence || generated[:customer_message].presence

    request = create_approval_request(conversation, reason, final_options)
    deliver_messages(conversation, request, final_customer_message)
    ApprovalBot::NotifyJob.perform_later(request)
    request
  rescue StandardError => e
    Rails.logger.warn("[HandoffTool] approval pipeline failed for conversation #{conversation.id}: #{e.message}")
    nil
  end

  def generate_via_llm(conversation, reason, faq_snippets)
    Captain::Llm::HandoffApprovalGeneratorService.new(
      assistant: @assistant,
      conversation: conversation,
      reason: reason,
      faq_snippets: faq_snippets
    ).generate
  end

  def pick_options(override_options, generated_options, faq_snippets)
    candidates = sanitize_labels(override_options)
    candidates = sanitize_labels(generated_options) if candidates.empty?
    candidates = faq_snippets.first(2) if candidates.empty?
    candidates
  end

  def sanitize_labels(labels)
    Array(labels).compact.map(&:to_s).map(&:strip).reject(&:blank?)
  end

  def create_approval_request(conversation, reason, options)
    assignee_type, assignee_id = resolve_assignee(conversation)
    Captain::ApprovalRequest.create!(
      account_id: @assistant.account_id,
      conversation: conversation,
      assistant: @assistant,
      title: reason.presence || 'Conversation escalated to human support',
      context: generate_context(conversation),
      options: build_options(options),
      assignee_type: assignee_type,
      assignee_id: assignee_id,
      expires_at: 1.hour.from_now
    )
  end

  def resolve_assignee(conversation)
    assignee = conversation.assignee
    return ['user', assignee.id] if assignee.is_a?(User)
    return ['team', conversation.team_id] if conversation.team_id.present?

    [nil, nil]
  end

  def build_options(labels)
    result = labels.map do |label|
      { label: label, action_type: 'reply_to_customer', action_payload: {} }
    end
    result << { label: I18n.t('approval_bot.suggest_your_own'), action_type: 'free_text' }
    result
  end

  def deliver_messages(conversation, request, customer_message)
    send_customer_text(conversation, customer_message)
    send_dashboard_input_select(conversation, request)
  end

  def send_customer_text(conversation, customer_message)
    content = customer_message.presence || I18n.t('captain.clarifying_with_operator')
    return if content.blank?

    conversation.messages.create!(
      message_type: :outgoing,
      account_id: @assistant.account_id,
      inbox_id: conversation.inbox_id,
      sender: @assistant,
      content: content
    )
  rescue StandardError => e
    Rails.logger.warn("[HandoffTool] customer message failed for conversation #{conversation.id}: #{e.message}")
  end

  def send_dashboard_input_select(conversation, request)
    conversation.messages.create!(
      message_type: :outgoing,
      private: true,
      account_id: @assistant.account_id,
      inbox_id: conversation.inbox_id,
      sender: @assistant,
      content: request.title,
      content_type: :input_select,
      content_attributes: {
        items: request.options.map { |opt| { title: opt[:label] || opt['label'], value: opt[:label] || opt['label'] } },
        approval_request_id: request.id
      }
    )
  rescue StandardError => e
    Rails.logger.warn("[HandoffTool] dashboard input_select failed for conversation #{conversation.id}: #{e.message}")
  end

  def collect_faq_snippets(tool_context)
    snippets = snippets_from_last_faq_lookup(tool_context)
    snippets = proactive_faq_snippets(tool_context) if snippets.empty?
    snippets
  end

  def snippets_from_last_faq_lookup(tool_context)
    last_faq_lookup = tool_context.state&.dig(:orchestration, :last_faq_lookup)
    return [] unless last_faq_lookup.is_a?(Hash)

    answer_draft = last_faq_lookup.with_indifferent_access['answer_draft']
    return [] if answer_draft.blank?

    extract_answer_snippets(answer_draft).first(2)
  end

  # When the LLM escalates without first calling faq_lookup (common for cancellation/refund
  # intents that are policy-routed to handoff), do a last-mile FAQ search so the generator and
  # the operator both see concrete reference snippets.
  def proactive_faq_snippets(tool_context)
    query = proactive_faq_query(tool_context)
    return [] if query.blank?

    results = Captain::Knowledge::UnifiedSearchService.new(assistant: @assistant).search(query)
    snippets = results.first(2).filter_map { |r| extract_proactive_snippet(r) }
    return [] if snippets.blank?

    record_proactive_lookup(tool_context, query, snippets)
    snippets
  rescue StandardError => e
    Rails.logger.warn("[HandoffTool] Proactive FAQ lookup failed: #{e.message}")
    []
  end

  def proactive_faq_query(tool_context)
    last_user = tool_context.state&.dig(:conversation, :last_user_message_text).to_s
    return last_user if last_user.present?

    conversation = find_conversation(tool_context.state)
    return nil unless conversation

    conversation.messages
                .where(message_type: :incoming, private: false)
                .order(created_at: :desc)
                .limit(1)
                .pick(:content)
  end

  def extract_proactive_snippet(result)
    raw = result.respond_to?(:content) ? result.content.to_s : ''
    answer_match = raw.match(/Answer:\s*(.+?)(?=\n\s*Question:|\n\s*\[REQUIRES|\z)/m)
    text = answer_match ? answer_match[1] : raw
    text = text.gsub(/\s+/, ' ').strip
    text.presence&.truncate(160)
  end

  def record_proactive_lookup(tool_context, query, snippets)
    tool_context.state[:orchestration] ||= {}
    tool_context.state[:orchestration][:handoff_proactive_faq] = {
      query: query.to_s.truncate(300),
      options: snippets,
      found_count: snippets.size
    }
  end

  def extract_answer_snippets(answer_draft)
    matches = answer_draft.to_s.scan(/Answer:\s*(.+?)(?=\n\s*Question:|\z)/m).flatten
    snippets = matches.map { |text| text.gsub(/\s+/, ' ').strip }.reject(&:blank?)
    snippets = [answer_draft.to_s.gsub(/\s+/, ' ').strip] if snippets.blank?

    snippets.map { |text| text.truncate(160) }
  end

  def generate_context(conversation)
    messages = conversation.messages.order(:created_at).to_a
    summarizer = Captain::ConversationSummarizerService.new(conversation: conversation, message_history: messages)
    summary_result = summarizer.call
    summary_result&.dig(:summary) || messages.last(5).filter_map(&:content).join("\n").truncate(300)
  rescue StandardError => e
    Rails.logger.warn("[HandoffTool] Failed to summarize conversation #{conversation.id}: #{e.message}")
    conversation.messages.last(3).filter_map(&:content).join("\n").truncate(200)
  end

  def send_out_of_office_message_if_applicable(conversation)
    ::MessageTemplates::Template::OutOfOffice.perform_if_applicable(conversation)
  end
end
