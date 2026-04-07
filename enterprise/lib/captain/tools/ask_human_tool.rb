# frozen_string_literal: true

class Captain::Tools::AskHumanTool < Captain::Tools::BasePublicTool
  description 'Use this tool to silently ask a human operator a background question or to request approval for a ' \
              'restricted action (e.g., canceling an order). The conversation will NOT be handed off; you remain ' \
              'active and receive a hidden response from the operator to continue the chat with the user.'
  param :title, type: 'string', desc: 'The question or request for the operator', required: true
  param :target, type: 'string',
                 desc: 'Optional: "@member:user_id" for a specific agent. Default: first decision maker from assistant config.',
                 required: false
  param :options, type: 'array',
                  desc: 'Array of response options for the operator (last should be a free-text option). Each is a string label.',
                  required: false
  param :action_type, type: 'string',
                      desc: 'What to do with the selected option: "reply_to_customer", "resume_captain", or "external_api_call"',
                      required: false

  def perform(tool_context, title:, target: nil, options: nil, action_type: nil)
    conversation = find_conversation(tool_context.state)
    return { status: 'error', message: 'Conversation not found' } unless conversation

    resolved = resolve_ask_human_assignee(target)
    return resolved if resolved.is_a?(String)

    assignee_type, assignee_id = resolved

    log_tool_usage('ask_human', { conversation_id: conversation.id, target: target.presence || "user:#{assignee_id}" })
    action = action_type.presence || 'reply_to_customer'
    request = Captain::ApprovalRequest.create!(
      account_id: @assistant.account_id, conversation: conversation, assistant: @assistant,
      title: title, context: generate_context(conversation), options: build_options(options, action),
      assignee_type: assignee_type, assignee_id: assignee_id, expires_at: 30.minutes.from_now
    )
    persist_pending_interaction(conversation, request, tool_context, title, action)
    send_clarifying_message(conversation, request)
    ApprovalBot::NotifyJob.perform_later(request)

    {
      status: 'awaiting_human',
      interaction_id: request.id,
      waiting_tool_name: name,
      requested_at: request.created_at.iso8601,
      action_type: action,
      assignee: target.presence || "user:#{assignee_id}",
      message: "Approval request ##{request.id} sent. Wait for the operator response before replying to the customer."
    }
  end

  private

  # @return [Array(String, Integer)] assignee_type and assignee_id, or an error String
  def resolve_ask_human_assignee(target)
    if target.present?
      assignee_type, assignee_id = parse_target(target)
      return "Invalid target format: #{target}. Use @member:id" unless assignee_id

      return [assignee_type, assignee_id]
    end

    dm_ids = @assistant.config['decision_maker_ids'] || []
    return 'No human decision maker is configured to handle this. Proceed with standard human escalation if required.' if dm_ids.blank?

    user = first_decision_maker_with_telegram(dm_ids)
    return 'No human decision maker with a configured Telegram account was found. Proceed with standard human escalation if required.' unless user

    ['user', user.id]
  end

  def first_decision_maker_with_telegram(dm_ids)
    account_id = @assistant.account_id
    users_by_id = ::User.joins(:account_users)
                        .where(account_users: { account_id: account_id })
                        .where(id: dm_ids)
                        .index_by(&:id)

    dm_ids.filter_map { |raw_id| users_by_id[raw_id.to_i] }.find { |u| u.telegram_chat_id.present? }
  end

  def parse_target(target)
    case target
    when /\A@member:(\d+)\z/
      user_id = ::Regexp.last_match(1).to_i
      user = ::User.joins(:account_users).where(account_users: { account_id: @assistant.account_id }).find_by(id: user_id)
      user ? ['user', user.id] : [nil, nil]
    else
      [nil, nil]
    end
  end

  def build_options(labels, action_type)
    result = (labels || []).map do |label|
      { label: label, action_type: action_type, action_payload: {} }
    end
    result << { label: I18n.t('approval_bot.suggest_your_own'), action_type: 'free_text' }
    result
  end

  def persist_pending_interaction(conversation, request, tool_context, title, action)
    runtime_state = Captain::RuntimeStateService.new(conversation)
    snapshot = {
      message_count: conversation.messages.count,
      last_message_id: conversation.messages.order(:created_at).last&.id,
      requested_at: request.created_at.iso8601
    }
    pending = {
      status: 'awaiting_human',
      interaction_id: request.id,
      waiting_tool_name: name,
      title: title,
      action_type: action,
      snapshot: snapshot
    }

    runtime_state.update_state(
      pending_human_interaction: pending,
      last_human_interaction_id: request.id
    )
    tool_context.state[:orchestration] ||= {}
    tool_context.state[:orchestration][:pending_human_interaction] = pending
  end

  def generate_context(conversation)
    messages = conversation.messages.order(:created_at).to_a
    summarizer = Captain::ConversationSummarizerService.new(conversation: conversation, message_history: messages)
    summary_result = summarizer.call
    summary_result&.dig(:summary) || messages.last(5).filter_map(&:content).join("\n").truncate(300)
  rescue StandardError => e
    Rails.logger.warn("[AskHumanTool] Failed to summarize conversation #{conversation.id}: #{e.message}")
    conversation.messages.last(3).filter_map(&:content).join("\n").truncate(200)
  end

  def send_clarifying_message(conversation, request)
    conversation.messages.create!(
      message_type: :outgoing,
      account_id: @assistant.account_id,
      inbox_id: conversation.inbox_id,
      sender: @assistant,
      content: I18n.t('captain.clarifying_with_operator'),
      content_type: :input_select,
      content_attributes: {
        items: request.options.map { |opt| { title: opt[:label] || opt['label'], value: opt[:label] || opt['label'] } },
        approval_request_id: request.id
      }
    )
  end
end
