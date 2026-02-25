# frozen_string_literal: true

class Webhooks::AvitoController < ActionController::API
  def process_payload
    # Avito requires response within 2 seconds, so process asynchronously
    Webhooks::AvitoEventsJob.perform_later(
      params.to_unsafe_hash.with_indifferent_access,
      params[:avito_user_id]
    )
    head :ok
  end
end
