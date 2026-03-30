# frozen_string_literal: true

class ApprovalBot::FollowUpNotifyJob < ApplicationJob
  queue_as :default

  def perform(approval_request)
    @request = approval_request
    return unless @request.resolved?

    new_message = latest_incoming_message_after_resolve
    return unless new_message

    notify_operator(new_message)
  end

  private

  def latest_incoming_message_after_resolve
    @request.conversation.messages
            .where(message_type: :incoming)
            .where('created_at > ?', @request.updated_at)
            .order(created_at: :desc)
            .first
  end

  def notify_operator(message)
    preview = message.content.to_s.truncate(100)
    text = "💬 #{I18n.t('approval_bot.customer_replied')}\n\"#{preview}\""
    keyboard = build_follow_up_keyboard

    resolved_user = @request.resolved_by
    return if resolved_user&.telegram_chat_id.blank?

    config = @request.account.approval_bot_configs.enabled.find_by(channel_type: 'telegram')
    return unless config

    sender = ApprovalBot::Telegram::SenderService.new(config: config)
    sender.send_message(chat_id: resolved_user.telegram_chat_id, text: text, reply_markup: keyboard)
  end

  def build_follow_up_keyboard
    {
      inline_keyboard: [
        [
          { text: "📄 #{I18n.t('approval_bot.view_summary')}", callback_data: "summary::#{@request.conversation_id}" },
          { text: "👤 #{I18n.t('approval_bot.take_over')}", callback_data: "takeover::#{@request.conversation_id}" }
        ]
      ]
    }
  end
end
