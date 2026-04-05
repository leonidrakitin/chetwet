# frozen_string_literal: true

class Notification::TelegramNotificationService
  include Rails.application.routes.url_helpers

  pattr_initialize [:notification!]

  def perform
    return unless user_subscribed_to_notification?
    return unless bot_token.present?
    return unless chat_id.present?

    send_telegram_message
  end

  private

  delegate :user, to: :notification
  delegate :notification_settings, to: :user

  def user_subscribed_to_notification?
    notification_setting = notification_settings.find_by(account_id: notification.account.id)
    return true if notification_setting.public_send("telegram_#{notification.notification_type}?")

    false
  end

  def chat_id
    user.telegram_chat_id.presence
  end

  def bot_token
    @bot_token ||= notification.account
                               .approval_bot_configs
                               .enabled
                               .find_by(channel_type: 'telegram')
                               &.bot_token
  end

  def send_telegram_message
    text = "#{notification.push_message_title}\n\n#{notification.push_message_body}"
    url = app_account_conversation_url(account_id: notification.account_id, id: notification.conversation.display_id)
    text += "\n\n#{url}"

    response = HTTParty.post(
      "#{telegram_api_url}/sendMessage",
      body: {
        chat_id: chat_id,
        text: text,
        disable_web_page_preview: true
      }
    )

    if response.success?
      Rails.logger.info("Telegram notification sent to #{user.email} (#{chat_id})")
    else
      Rails.logger.warn("Telegram notification failed for #{user.email}: #{response.parsed_response}")
    end
  end

  def telegram_api_url
    "https://api.telegram.org/bot#{bot_token}"
  end
end
