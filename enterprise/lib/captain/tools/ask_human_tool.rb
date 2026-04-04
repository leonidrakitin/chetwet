# frozen_string_literal: true

class Captain::Tools::AskHumanTool < Captain::Tools::BasePublicTool
  description 'Request operator/human approval or clarification via messenger (Telegram/VK/Max). ' \
              'Use when you are unsure about the answer or need to confirm an action with a human.'
  param :title, type: 'string', desc: 'The question or request for the operator', required: true
  param :target, type: 'string',
                 desc: 'Who to ask: "@team:team_slug" for a team, or "@member:user_id" for a specific agent (optional)',
                 required: false
  param :options, type: 'array',
                  desc: 'Array of response options for the operator (last should be a free-text option). Each is a string label.',
                  required: false
  param :action_type, type: 'string',
                      desc: 'What to do with the selected option: "reply_to_customer", "resume_captain", or "external_api_call"',
                      required: false

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength -- TEMP DEBUG TMP logging (revert commit)
  def perform(tool_context, title:, target: nil, options: nil, action_type: nil)
    conversation = find_conversation(tool_context.state)
    Rails.logger.info(
      '[Captain DEBUG TMP] AskHumanTool#perform enter ' \
      "assistant_id=#{@assistant.id} conversation_id=#{conversation&.id} title=#{title.inspect} target=#{target.inspect}"
    )
    return 'Conversation not found'.tap { |msg| Rails.logger.info("[Captain DEBUG TMP] AskHumanTool#perform abort: #{msg}") } unless conversation

    resolved = resolve_ask_human_assignee(target)
    if resolved.is_a?(String)
      Rails.logger.info("[Captain DEBUG TMP] AskHumanTool#perform early_return_string=#{resolved.truncate(300).inspect}")
      return resolved
    end

    assignee_type, assignee_id = resolved
    Rails.logger.info(
      '[Captain DEBUG TMP] AskHumanTool#perform resolved_assignee ' \
      "assignee_type=#{assignee_type.inspect} assignee_id=#{assignee_id.inspect}"
    )

    log_tool_usage('ask_human', { conversation_id: conversation.id, target: target.presence || "user:#{assignee_id}" })
    send_clarifying_message(conversation)

    action = action_type.presence || 'reply_to_customer'
    request = Captain::ApprovalRequest.create!(
      account_id: @assistant.account_id, conversation: conversation, assistant: @assistant,
      title: title, context: generate_context(conversation), options: build_options(options, action),
      assignee_type: assignee_type, assignee_id: assignee_id, expires_at: 30.minutes.from_now
    )
    ApprovalBot::NotifyJob.perform_later(request)

    out = "Approval request ##{request.id} sent to #{target}. Waiting for human response. " \
          'Do NOT send any message to the customer until the operator responds.'
    Rails.logger.info(
      '[Captain DEBUG TMP] AskHumanTool#perform SUCCESS ' \
      "approval_request_id=#{request.id} notify_job=enqueued result=#{out.truncate(200).inspect}"
    )
    out
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  private

  # @return [Array(String, Integer)] assignee_type and assignee_id, or an error String
  def resolve_ask_human_assignee(target)
    if target.present?
      assignee_type, assignee_id = parse_target(target)
      return "Invalid target format: #{target}. Use @team:slug or @member:id" unless assignee_id

      return [assignee_type, assignee_id]
    end

    dm_ids = @assistant.config['decision_maker_ids'] || []
    Rails.logger.info("[Captain DEBUG TMP] AskHumanTool#resolve_ask_human_assignee dm_ids=#{dm_ids.inspect}")
    return 'No human decision maker is configured to handle this. Proceed with standard conversation handoff.' if dm_ids.blank?

    user = first_decision_maker_with_telegram(dm_ids)
    unless user
      Rails.logger.info('[Captain DEBUG TMP] AskHumanTool#resolve_ask_human_assignee no user with telegram in dm_ids list')
      return 'No human decision maker with a configured Telegram account was found. Proceed with standard conversation handoff.'
    end

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
    when /\A@team:(.+)\z/
      team = account_scoped(::Team).find_by(slug: ::Regexp.last_match(1)) || account_scoped(::Team).find_by(name: ::Regexp.last_match(1))
      team ? ['team', team.id] : [nil, nil]
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

  def generate_context(conversation)
    messages = conversation.messages.order(:created_at).to_a
    summarizer = Captain::ConversationSummarizerService.new(conversation: conversation, message_history: messages)
    summary_result = summarizer.call
    summary_result&.dig(:summary) || messages.last(5).filter_map(&:content).join("\n").truncate(300)
  rescue StandardError => e
    Rails.logger.warn("[AskHumanTool] Failed to summarize conversation #{conversation.id}: #{e.message}")
    conversation.messages.last(3).filter_map(&:content).join("\n").truncate(200)
  end

  def send_clarifying_message(conversation)
    conversation.messages.create!(
      message_type: :outgoing,
      account_id: @assistant.account_id,
      inbox_id: conversation.inbox_id,
      sender: @assistant,
      content: I18n.t('captain.clarifying_with_operator')
    )
  end
end
