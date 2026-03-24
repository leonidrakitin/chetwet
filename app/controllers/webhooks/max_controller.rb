# frozen_string_literal: true

class Webhooks::MaxController < ActionController::API
  def process_payload
    channel = find_channel
    if channel
      payload = params.to_unsafe_hash.with_indifferent_access
      Webhooks::MaxEventsJob.perform_later(payload, channel.id)
    end
    head :ok
  end

  private

  def find_channel
    inbox = Inbox.find_by(id: params[:inbox_id], account_id: params[:account_id])
    return nil unless inbox&.channel.is_a?(Channel::Max)

    inbox.channel
  end
end
