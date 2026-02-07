# frozen_string_literal: true

class Webhooks::VkEventsJob < ApplicationJob
  queue_as :default

  def perform(params = {})
    params = params.with_indifferent_access
    return if params[:type] == 'confirmation'

    group_id = params[:group_id]&.to_s
    channel = Channel::Vk.find_by(group_id: group_id)

    if channel_is_inactive?(channel)
      log_inactive_channel(channel, params)
      return
    end

    process_event_params(channel, params)
  end

  private

  def channel_is_inactive?(channel)
    return true if channel.blank?
    return true unless channel.account.active?

    false
  end

  def log_inactive_channel(channel, params)
    message = if channel&.id
                "Account #{channel.account.id} is not active for channel #{channel.id}"
              else
                "Channel not found for group_id: #{params[:group_id]}"
              end
    Rails.logger.warn("VK event discarded: #{message}")
  end

  def process_event_params(channel, params)
    case params[:type]
    when 'message_new'
      object = params[:object] || {}
      Vk::IncomingMessageService.new(inbox: channel.inbox, params: object.with_indifferent_access).perform
    when 'message_typing_state'
      object = params[:object] || {}
      Vk::TypingStatusService.new(inbox: channel.inbox, params: object.with_indifferent_access).perform
    end
  end
end
