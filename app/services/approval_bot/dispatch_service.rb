# frozen_string_literal: true

class ApprovalBot::DispatchService
  def self.sender_for(config)
    case config.channel_type
    when 'telegram' then ApprovalBot::Telegram::SenderService.new(config: config)
    when 'vk'       then ApprovalBot::Vk::SenderService.new(config: config)
    when 'max'      then ApprovalBot::Max::SenderService.new(config: config)
    end
  end

  def initialize(approval_request:)
    @approval_request = approval_request
  end

  def perform
    account.approval_bot_configs.enabled.each do |config|
      sender = channel_sender_for(config)
      target_users.each do |user|
        next unless sender.agent_reachable?(user)

        sender.send_approval_request(user: user, request: @approval_request)
      end
    end
  end

  private

  def account
    @approval_request.account
  end

  def target_users
    @approval_request.target_users
  end

  def channel_sender_for(config)
    self.class.sender_for(config)
  end
end
