class Webhooks::EvolutionApiController < ActionController::API
  def process_payload
    return head :ok unless processable_event?

    Webhooks::WhatsappEventsJob.perform_later(params.to_unsafe_hash.merge(provider: 'evolution_api'))
    head :ok
  end

  private

  def processable_event?
    event = params[:event]
    return false if event.blank?

    # Only process incoming messages and status updates
    return false unless %w[messages.upsert messages.update].include?(event)

    # Skip messages sent by us (fromMe)
    return false if event == 'messages.upsert' && params.dig(:data, :key, :fromMe) == true

    true
  end
end
