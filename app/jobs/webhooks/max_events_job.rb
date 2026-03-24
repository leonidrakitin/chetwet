# frozen_string_literal: true

class Webhooks::MaxEventsJob < ApplicationJob
  queue_as :default

  def perform(params = {}, channel_id = nil)
    params = params.with_indifferent_access
    channel = Channel::Max.find_by(id: channel_id)

    if channel_is_inactive?(channel)
      log_inactive_channel(channel, channel_id)
      return
    end

    Rails.logger.info "[MAX] Processing event type=#{params[:update_type]} for channel #{channel.id}"
    process_event(channel, params)
  end

  private

  def channel_is_inactive?(channel)
    return true if channel.blank?
    return true unless channel.account.active?

    false
  end

  def log_inactive_channel(channel, channel_id)
    message = if channel&.id
                "Account #{channel.account.id} is not active for channel #{channel.id}"
              else
                "Channel not found: #{channel_id}"
              end
    Rails.logger.warn("[MAX] Event discarded: #{message}")
  end

  def process_event(channel, params)
    case params[:update_type]
    when 'message_created', 'message_callback', 'bot_started'
      Max::IncomingMessageService.new(inbox: channel.inbox, params: params).perform
    else
      Rails.logger.info "[MAX] Unhandled event type: #{params[:update_type]}"
    end
  rescue StandardError => e
    Rails.logger.error "[MAX] Event processing error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end
