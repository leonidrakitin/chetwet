class Webhooks::TelegramController < ActionController::API
  def process_payload
    payload = params.to_unsafe_hash.with_indifferent_access
    payload[:bot_token] ||= resolve_bot_token
    Webhooks::TelegramEventsJob.perform_later(payload)
    head :ok
  end

  private

  def resolve_bot_token
    ENV.fetch('TELEGRAM_CALLBACK_BOT_TOKEN', nil).presence || single_telegram_channel_bot_token
  end

  def single_telegram_channel_bot_token
    channels = Channel::Telegram.limit(2).to_a
    channels.first&.bot_token if channels.size == 1
  end
end
