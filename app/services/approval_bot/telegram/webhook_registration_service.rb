# frozen_string_literal: true

class ApprovalBot::Telegram::WebhookRegistrationService
  def initialize(config:)
    @config = config
  end

  def perform
    delete_existing_webhook
    register_webhook
    fetch_bot_name
  rescue StandardError => e
    Rails.logger.error("[ApprovalBot] Telegram webhook registration failed: #{e.message}")
  end

  private

  def delete_existing_webhook
    HTTParty.post("#{api_url}/deleteWebhook")
  end

  def register_webhook
    webhook_url = "#{ENV.fetch('FRONTEND_URL', nil)}/webhooks/approval_bot/telegram/#{@config.bot_token}"
    response = HTTParty.post("#{api_url}/setWebhook", body: { url: webhook_url })
    return if response.success? && response.parsed_response['ok']

    Rails.logger.error("[ApprovalBot] setWebhook failed: #{response.parsed_response}")
  end

  def fetch_bot_name
    response = HTTParty.get("#{api_url}/getMe")
    return unless response.success?

    username = response.parsed_response.dig('result', 'username')
    @config.update_columns(bot_name: username) if username.present?
  end

  def api_url
    "https://api.telegram.org/bot#{@config.bot_token}"
  end
end
