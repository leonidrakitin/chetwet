# frozen_string_literal: true

class Captain::Tools::NotifyStaffTool < Captain::Tools::BasePublicTool
  description 'Notify a specific staff member via messenger (Telegram/VK/Max). ' \
              'Use to inform staff about events or request a response.'
  param :staff_id, type: 'integer', desc: 'User ID of the staff member to notify', required: true
  param :message, type: 'string', desc: 'Notification message for the staff member', required: true
  param :require_response, type: 'boolean', desc: 'Whether to wait for staff response (default: false)', required: false
  param :options, type: 'array',
                  desc: 'Array of response options (only used when require_response is true). Each is a string label.',
                  required: false
  param :action_type, type: 'string',
                      desc: 'What to do with the selected option: "reply_to_customer", "resume_captain", or "external_api_call"',
                      required: false

  def perform(tool_context, staff_id:, message:, require_response: false, options: nil, action_type: nil)
    conversation = find_conversation(tool_context.state)
    return 'Conversation not found' unless conversation

    user = ::User.joins(:account_users)
                 .where(account_users: { account_id: @assistant.account_id })
                 .find_by(id: staff_id)
    return "Staff member with ID #{staff_id} not found in this account" unless user

    log_tool_usage('notify_staff', { conversation_id: conversation.id, staff_id: staff_id, require_response: require_response })

    if require_response
      create_approval_request(conversation, user, message, options, action_type)
    else
      send_simple_notification(conversation, user, message)
    end
  end

  private

  def create_approval_request(conversation, user, message, labels, action_type)
    action = action_type.presence || 'reply_to_customer'
    approval_options = build_options(labels, action)
    context = generate_context(conversation)

    request = Captain::ApprovalRequest.create!(
      account_id: @assistant.account_id,
      conversation: conversation,
      assistant: @assistant,
      title: message,
      context: context,
      options: approval_options,
      assignee_type: 'user',
      assignee_id: user.id,
      expires_at: 30.minutes.from_now
    )

    ApprovalBot::NotifyJob.perform_later(request)

    "Approval request ##{request.id} sent to staff member #{user.name}. Waiting for response."
  end

  def send_simple_notification(conversation, user, message)
    configs = account_scoped(::ApprovalBotConfig).enabled
    return 'No messenger channels configured' if configs.empty?

    sent = false
    configs.each do |config|
      sender = ApprovalBot::DispatchService.sender_for(config)
      next unless sender.agent_reachable?(user)

      context = "#{I18n.t('approval_bot.conversation_ref', id: conversation.display_id)}\n#{message}"
      sender.send_message(chat_id: user.telegram_chat_id, text: context)
      sent = true
    end

    sent ? "Notification sent to #{user.name}." : "Could not reach staff member #{user.name} via any configured channel."
  end

  def build_options(labels, action_type)
    result = (labels || []).map do |label|
      { label: label, action_type: action_type, action_payload: {} }
    end
    result << { label: I18n.t('approval_bot.suggest_your_own'), action_type: 'free_text' }
    result
  end

  def generate_context(conversation)
    messages = conversation.messages.order(:created_at).to_a
    summarizer = Captain::ConversationSummarizerService.new(conversation: conversation, message_history: messages)
    summary_result = summarizer.call
    summary_result&.dig(:summary) || messages.last(5).filter_map(&:content).join("\n").truncate(300)
  rescue StandardError => e
    Rails.logger.warn("[NotifyStaffTool] Failed to summarize conversation #{conversation.id}: #{e.message}")
    conversation.messages.last(3).filter_map(&:content).join("\n").truncate(200)
  end
end
