# frozen_string_literal: true

class Webhooks::ApprovalBotController < ActionController::API
  before_action :find_config

  def telegram
    payload = params.to_unsafe_hash.with_indifferent_access
    ApprovalBot::Telegram::CallbackJob.perform_later(payload, @config.id)
    head :ok
  end

  # Stubs — to be implemented when VK/Max support is added
  def vk
    head :ok
  end

  def max
    head :ok
  end

  private

  def find_config
    channel_type = action_name # "telegram", "vk", or "max"
    @config = ApprovalBotConfig.enabled.find_by(
      bot_token: params[:bot_token],
      channel_type: channel_type
    )
    head :not_found unless @config
  end
end
