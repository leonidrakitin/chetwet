# frozen_string_literal: true

class Webhooks::VkEventsJob < ApplicationJob
  queue_as :default

  EVENT_HANDLERS = {
    'message_new' => :handle_message_new,
    'message_reply' => :handle_message_reply,
    'message_typing_state' => :handle_message_typing_state,
    'message_edit' => :handle_message_edit,
    'message_deny' => :handle_message_deny,
    'message_allow' => :handle_message_allow
  }.freeze

  def perform(params = {})
    params = params.with_indifferent_access
    return if params[:type] == 'confirmation'

    group_id = params[:group_id]&.to_s
    Rails.logger.info "[VK] Processing event type=#{params[:type]} for group_id=#{group_id}"

    normalized_id = group_id.to_s.delete_prefix('-')
    channel = find_vk_channel(normalized_id)

    if channel_is_inactive?(channel)
      log_inactive_channel(channel, params)
      return
    end

    Rails.logger.info "[VK] Found active channel #{channel.id} for inbox #{channel.inbox.id}"
    process_event_params(channel, params)
  end

  private

  def find_vk_channel(normalized_id)
    return nil if normalized_id.blank?

    Channel::Vk.find_by(group_id: normalized_id) ||
      Channel::Vk.find_by(group_id: "-#{normalized_id}")
  end

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
    handler = EVENT_HANDLERS[params[:type]]
    return unless handler

    send(handler, channel, params)
  rescue StandardError => e
    Rails.logger.error "[VK] Event processing error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  def event_object(params)
    (params[:object] || {}).with_indifferent_access
  end

  def handle_message_new(channel, params)
    Rails.logger.info "[VK] Processing message_new for inbox #{channel.inbox.id}"
    Vk::IncomingMessageService.new(inbox: channel.inbox, params: event_object(params)).perform
  end

  def handle_message_reply(channel, params)
    object = event_object(params)
    return unless object['out'] == 1 || object[:out] == 1

    Rails.logger.info "[VK] Processing message_reply (admin) for inbox #{channel.inbox.id}"
    Vk::OutgoingMessageSyncService.new(inbox: channel.inbox, params: object).perform
  end

  def handle_message_typing_state(channel, params)
    Vk::TypingStatusService.new(inbox: channel.inbox, params: event_object(params)).perform
  end

  def handle_message_edit(channel, params)
    Rails.logger.info "[VK] Processing message_edit for inbox #{channel.inbox.id}"
    Vk::UpdateMessageService.new(inbox: channel.inbox, params: event_object(params)).perform
  end

  def handle_message_deny(channel, params)
    Rails.logger.info "[VK] Processing message_deny for inbox #{channel.inbox.id}"
    Vk::MessagePermissionService.new(inbox: channel.inbox, params: event_object(params), action: :deny).perform
  end

  def handle_message_allow(channel, params)
    Rails.logger.info "[VK] Processing message_allow for inbox #{channel.inbox.id}"
    Vk::MessagePermissionService.new(inbox: channel.inbox, params: event_object(params), action: :allow).perform
  end
end
