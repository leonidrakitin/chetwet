# frozen_string_literal: true

class ApprovalBot::ExpireRequestsJob < ApplicationJob
  queue_as :low

  def perform
    Captain::ApprovalRequest
      .pending
      .where('expires_at IS NOT NULL AND expires_at < ?', Time.current)
      .find_each do |request|
        request.update!(status: :expired)
      end
  end
end
