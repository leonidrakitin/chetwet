class Captain::Tools::HandoffTool < Captain::Tools::BasePublicTool
  description 'Escalate the conversation to the human support team. The operator will be notified via Telegram ' \
              'if they have it configured. Use this tool when the user explicitly asks for a human agent, when the ' \
              'issue requires operator judgment, or when FAQ lookup indicates operator clarification is needed.'
  param :reason, type: 'string', desc: 'The reason why human escalation is needed (optional)', required: false
  param :post_reason_as_note, type: 'boolean',
                              desc: 'If false, do not create a private note with the reason ' \
                                    '(use when you already added a note via Add Private Note)',
                              required: false

  def name
    'escalate_to_human'
  end

  def perform(tool_context, reason: nil, post_reason_as_note: true)
    conversation = find_conversation(tool_context.state)
    return 'Conversation not found' unless conversation

    log_tool_usage('tool_human_escalation', {
                     conversation_id: conversation.id,
                     reason: reason || 'Agent requested human escalation'
                   })

    trigger_handoff(conversation, reason, post_reason_as_note)
    notify_operator_via_telegram(conversation, reason)

    "Conversation escalated to human support team#{" (Reason: #{reason})" if reason}"
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
    'Failed to escalate conversation to human support'
  end

  private

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

  def notify_operator_via_telegram(conversation, reason)
    user = resolve_notification_target(conversation)
    return unless user

    context_text = generate_context(conversation)
    request = Captain::ApprovalRequest.create!(
      account_id: @assistant.account_id,
      conversation: conversation,
      assistant: @assistant,
      title: reason.presence || 'Conversation escalated to human support',
      context: context_text,
      options: [{ label: I18n.t('approval_bot.suggest_your_own'), action_type: 'free_text' }],
      assignee_type: 'user',
      assignee_id: user.id,
      expires_at: 1.hour.from_now
    )
    ApprovalBot::NotifyJob.perform_later(request)
  rescue StandardError => e
    Rails.logger.warn("[HandoffTool] Telegram notification failed for conversation #{conversation.id}: #{e.message}")
  end

  def resolve_notification_target(conversation)
    assignee = conversation.assignee
    return assignee if assignee.is_a?(User) && assignee.telegram_chat_id.present?

    dm_ids = @assistant.config['decision_maker_ids'] || []
    return nil if dm_ids.blank?

    account_id = @assistant.account_id
    users_by_id = ::User.joins(:account_users)
                        .where(account_users: { account_id: account_id })
                        .where(id: dm_ids)
                        .index_by(&:id)
    dm_ids.filter_map { |raw_id| users_by_id[raw_id.to_i] }.find { |u| u.telegram_chat_id.present? }
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
