# frozen_string_literal: true

class ApprovalBot::NotifyJob < ApplicationJob
  queue_as :default

  def perform(approval_request)
    ApprovalBot::DispatchService.new(approval_request: approval_request).perform
  end
end
