# frozen_string_literal: true

class ApprovalBot::Telegram::CallbackJob < ApplicationJob
  queue_as :default

  def perform(payload, config_id)
    config = ApprovalBotConfig.find(config_id)
    ApprovalBot::Telegram::CallbackHandlerService.new(
      payload: payload.with_indifferent_access,
      config: config
    ).perform
  end
end
