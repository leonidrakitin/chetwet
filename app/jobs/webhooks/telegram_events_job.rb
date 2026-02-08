class Webhooks::TelegramEventsJob < ApplicationJob
  queue_as :default

  def perform(params = {})
    params = params.with_indifferent_access
    return unless params[:bot_token]

    channel = Channel::Telegram.find_by(bot_token: params[:bot_token])

    if channel_is_inactive?(channel)
      log_inactive_channel(channel, params)
      return
    end

    process_event_params(channel, params)
  end

  private

  def channel_is_inactive?(channel)
    return true if channel.blank?
    return true unless channel.account.active?

    false
  end

  def log_inactive_channel(channel, params)
    message = if channel&.id
                "Account #{channel.account.id} is not active for channel #{channel.id}"
              else
                "Channel not found for bot_token: #{params[:bot_token]}"
              end
    Rails.logger.warn("Telegram event discarded: #{message}")
  end

  def process_event_params(channel, params)
    # Payload is the raw Telegram update (message, callback_query, etc.); bot_token comes from the URL
    telegram_params = params.except(:controller, :action, :bot_token).with_indifferent_access
    return if telegram_params.blank?

    if telegram_params.dig(:edited_message).present? || telegram_params.dig(:edited_business_message).present?
      Telegram::UpdateMessageService.new(inbox: channel.inbox, params: telegram_params).perform
    else
      Telegram::IncomingMessageService.new(inbox: channel.inbox, params: telegram_params).perform
    end
  end
end
