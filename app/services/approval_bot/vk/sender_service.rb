# frozen_string_literal: true

# Stub — to be implemented when VK approval bot support is added.
class ApprovalBot::Vk::SenderService < ApprovalBot::BaseSenderService
  def initialize(config:)
    @config = config
  end

  def agent_reachable?(_user)
    false
  end
end
