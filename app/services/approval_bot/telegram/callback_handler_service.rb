# frozen_string_literal: true

class ApprovalBot::Telegram::CallbackHandlerService
  include Redis::RedisKeys

  AWAITING_TEXT_TTL = 600 # 10 minutes
  DRAFT_TTL = 600 # 10 minutes
  # Private /start, /start PAYLOAD, and group-style /start@BotName (optional payload)
  START_COMMAND_PATTERN = %r{\A/start(?:@[A-Za-z0-9_]+)?(?:\s+(.+))?\z}

  def initialize(payload:, config:)
    @payload = payload.with_indifferent_access
    @config = config
  end

  def perform
    if callback_query?
      handle_callback_query
    elsif contact_message?
      handle_contact_share
    elsif start_command?
      handle_start_command
    elsif text_message?
      handle_text_reply
    end
  end

  private

  def handle_callback_query
    query     = @payload[:callback_query]
    chat_id   = query.dig(:from, :id).to_s
    data      = query[:data]
    query_id  = query[:id]

    sender.answer_callback(query_id)

    parts = data.to_s.split('::')

    case parts[0]
    when 'appr'
      handle_approval_callback(chat_id, parts[1], parts[2])
    when 'confirm_draft'
      handle_confirm_draft(chat_id, parts[1])
    when 'edit_draft'
      handle_edit_draft(chat_id, parts[1])
    when 'summary'
      handle_summary_callback(chat_id, parts[1])
    when 'takeover'
      handle_takeover_callback(chat_id, parts[1])
    end
  end

  def handle_approval_callback(chat_id, request_id, index_or_type)
    request = find_request(request_id)
    return sender.send_message(chat_id: chat_id, text: I18n.t('approval_bot.not_found')) unless request

    user = find_user_by_chat_id(chat_id)
    return unless user

    if index_or_type == ApprovalBot::Telegram::SenderService::FREE_TEXT_INDEX
      store_awaiting_text(chat_id, request_id)
      sender.send_message(chat_id: chat_id, text: I18n.t('approval_bot.type_your_response'))
    else
      generate_and_send_draft(chat_id, request, index_or_type.to_i)
    end
  end

  def generate_and_send_draft(chat_id, request, index)
    option = request.options[index]&.with_indifferent_access
    return unless option

    draft = ApprovalBot::DraftResponseService.new(request, index).generate
    draft = option[:label] if draft.blank?

    store_draft(chat_id, request.id, index, draft)

    text = "📝 <b>#{I18n.t('approval_bot.draft_header')}</b>\n\n#{draft}"
    keyboard = {
      inline_keyboard: [
        [
          { text: I18n.t('approval_bot.confirm_send'), callback_data: "confirm_draft::#{request.id}" },
          { text: I18n.t('approval_bot.suggest_your_own'), callback_data: "edit_draft::#{request.id}" }
        ]
      ]
    }.to_json

    sender.send_message(chat_id: chat_id, text: text, reply_markup: keyboard)
  end

  def handle_confirm_draft(chat_id, request_id)
    request = find_request(request_id)
    return sender.send_message(chat_id: chat_id, text: I18n.t('approval_bot.not_found')) unless request

    user = find_user_by_chat_id(chat_id)
    return unless user

    draft_data = load_draft(chat_id, request_id)
    unless draft_data
      sender.send_message(chat_id: chat_id, text: I18n.t('approval_bot.draft_expired'))
      return
    end

    clear_draft(chat_id, request_id)
    resolved = request.resolve!(index: draft_data[:index], custom_text: draft_data[:text], by_user_id: user.id)
    if resolved
      sender.mark_resolved(request: request, resolved_label: draft_data[:text].truncate(50))
      notify_other_team_members_resolved(request, user)
    else
      sender.send_message(chat_id: chat_id, text: I18n.t('approval_bot.already_handled', name: request.resolved_by&.name))
    end
  end

  def handle_edit_draft(chat_id, request_id)
    request = find_request(request_id)
    return sender.send_message(chat_id: chat_id, text: I18n.t('approval_bot.not_found')) unless request

    clear_draft(chat_id, request_id)
    store_awaiting_text(chat_id, request_id)
    sender.send_message(chat_id: chat_id, text: I18n.t('approval_bot.type_your_response'))
  end

  def handle_text_reply
    message = @payload[:message]
    chat_id = message.dig(:chat, :id).to_s
    text    = message[:text]

    awaiting = load_awaiting_text(chat_id)
    return unless awaiting

    request = find_request(awaiting[:request_id])
    return unless request

    user = find_user_by_chat_id(chat_id)
    return unless user

    clear_awaiting_text(chat_id)
    resolved = request.resolve!(index: last_option_index(request), custom_text: text, by_user_id: user.id)
    if resolved
      sender.mark_resolved(request: request, resolved_label: text.truncate(50))
      sender.send_message(chat_id: chat_id, text: I18n.t('approval_bot.sent'))
    else
      sender.send_message(chat_id: chat_id, text: I18n.t('approval_bot.already_handled', name: request.resolved_by&.name))
    end
  end

  def handle_summary_callback(chat_id, conversation_id)
    conversation = @config.account.conversations.find_by(id: conversation_id)
    return sender.send_message(chat_id: chat_id, text: I18n.t('approval_bot.not_found')) unless conversation

    messages = conversation.messages.order(:created_at).to_a
    summary_text = Captain::ConversationSummarizerService.new(
      conversation: conversation,
      message_history: messages
    ).call&.dig(:summary)

    sender.send_message(
      chat_id: chat_id,
      text: summary_text.presence || I18n.t('approval_bot.summary_unavailable')
    )
  end

  def handle_takeover_callback(chat_id, conversation_id)
    conversation = @config.account.conversations.find_by(id: conversation_id)
    return unless conversation

    user = find_user_by_chat_id(chat_id)
    return unless user

    conversation.update!(assignee: user)
    sender.send_message(chat_id: chat_id, text: I18n.t('approval_bot.taken_over'))
  end

  def notify_other_team_members_resolved(request, resolved_user)
    request.target_users.each do |user|
      next if user.id == resolved_user.id
      next if user.telegram_chat_id.blank?

      sender.send_message(
        chat_id: user.telegram_chat_id,
        text: I18n.t('approval_bot.already_handled', name: resolved_user.name)
      )
    end
  end

  # --- Draft storage (Redis) ---

  def store_draft(chat_id, request_id, index, text)
    key = draft_key(chat_id, request_id)
    ::Redis::Alfred.set(key, { index: index, text: text }.to_json, ex: DRAFT_TTL)
  end

  def load_draft(chat_id, request_id)
    key = draft_key(chat_id, request_id)
    raw = ::Redis::Alfred.get(key)
    return nil if raw.blank?

    JSON.parse(raw).with_indifferent_access
  end

  def clear_draft(chat_id, request_id)
    ::Redis::Alfred.delete(draft_key(chat_id, request_id))
  end

  def draft_key(chat_id, request_id)
    "approval_bot:draft:#{@config.account_id}:#{chat_id}:#{request_id}"
  end

  # --- Awaiting text storage (Redis) ---

  def store_awaiting_text(chat_id, request_id)
    key = awaiting_key(chat_id)
    ::Redis::Alfred.set(key, request_id.to_s, ex: AWAITING_TEXT_TTL)
  end

  def load_awaiting_text(chat_id)
    key = awaiting_key(chat_id)
    request_id = ::Redis::Alfred.get(key)
    return nil if request_id.blank?

    { request_id: request_id }
  end

  def clear_awaiting_text(chat_id)
    ::Redis::Alfred.delete(awaiting_key(chat_id))
  end

  def awaiting_key(chat_id)
    format(APPROVAL_BOT_AWAITING_TEXT, account_id: @config.account_id, chat_id: chat_id)
  end

  def find_request(request_id)
    Captain::ApprovalRequest.find_by(id: request_id, account_id: @config.account_id)
  end

  def find_user_by_chat_id(chat_id)
    User.joins(:account_users)
        .where(account_users: { account_id: @config.account_id }, telegram_chat_id: chat_id)
        .first
  end

  def last_option_index(request)
    request.options.length - 1
  end

  def sender
    @sender ||= ApprovalBot::Telegram::SenderService.new(config: @config)
  end

  def account_linker
    @account_linker ||= ApprovalBot::Telegram::AccountLinkerService.new(config: @config, sender: sender)
  end

  def handle_start_command
    text = @payload.dig(:message, :text).to_s.strip
    m = text.match(START_COMMAND_PATTERN)
    return unless m

    chat_id = @payload.dig(:message, :chat, :id).to_s
    token = m[1].to_s.strip

    if token.blank?
      sender.send_message(
        chat_id: chat_id,
        text: I18n.t('approval_bot.connect_use_dashboard_link')
      )
      return
    end

    account_linker.handle_start(chat_id, token)
  end

  def handle_contact_share
    chat_id = @payload.dig(:message, :chat, :id).to_s
    account_linker.handle_contact(chat_id)
  end

  def callback_query?
    @payload[:callback_query].present?
  end

  def contact_message?
    @payload.dig(:message, :contact).present?
  end

  def start_command?
    @payload.dig(:message, :text).to_s.strip.match?(START_COMMAND_PATTERN)
  end

  def text_message?
    @payload.dig(:message, :text).present?
  end
end
