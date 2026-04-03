# frozen_string_literal: true

class Webhooks::AvitoEventsJob < ApplicationJob
  queue_as :default

  def perform(params = {}, avito_user_id = nil)
    params = params.with_indifferent_access

    Rails.logger.info "[Avito] Processing webhook for avito_user_id=#{avito_user_id}, payload=#{params.to_json.truncate(500)}"

    channel = Channel::Avito.find_by(avito_user_id: avito_user_id.to_i)

    if channel_is_inactive?(channel)
      Rails.logger.warn "[Avito] Channel not found or inactive for avito_user_id=#{avito_user_id}"
      return
    end

    Rails.logger.info "[Avito] Found channel #{channel.id} for inbox #{channel.inbox.id}"
    process_event(channel, params)
  rescue StandardError => e
    Rails.logger.error "[Avito] AvitoEventsJob error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  private

  def channel_is_inactive?(channel)
    return true if channel.blank?
    return true unless channel.account.active?

    false
  end

  def process_event(channel, params)
    # Avito v3 webhook structure: { id, payload: { type: "message", value: WebhookMessage }, timestamp, version }
    payload = params[:payload] || params
    event_type = payload[:type] || params[:event_type] || 'message'

    return unless event_type == 'message'

    message_data = payload[:value] || payload
    return if message_data.blank?

    Avito::IncomingMessageService.new(
      inbox: channel.inbox,
      params: message_data.with_indifferent_access
    ).perform
  end
end
