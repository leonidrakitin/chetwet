# frozen_string_literal: true

class Yclients::Marketplace::ConnectJob < ApplicationJob
  queue_as :default

  # YClients requires callback within 1 hour; retry 3 times so we stay under that limit.
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  discard_on ActiveJob::DeserializationError

  def perform(account_id, salon_ids)
    results = Crm::Yclients::Marketplace::CallbackService.new(
      account_id: account_id,
      salon_ids: salon_ids
    ).call

    return if results[:errors].blank?

    Rails.logger.warn "YClients Marketplace ConnectJob completed with errors: #{results[:errors].inspect}"
  end
end
