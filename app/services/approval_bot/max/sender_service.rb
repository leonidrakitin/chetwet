# frozen_string_literal: true

# Stub — to be implemented when Max approval bot support is added.
class ApprovalBot::Max::SenderService < ApprovalBot::BaseSenderService
  def initialize(config:)
    @config = config
  end

  def agent_reachable?(_user)
    false
  end
end
