# frozen_string_literal: true

class Vk::SendOnVkService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Vk
  end

  def perform_reply
    result = channel.send_message_on_vk(message)
    return unless result

    update_attrs = { source_id: result[:message_id].to_s }
    update_attrs[:external_source_ids] = (message.external_source_ids || {}).merge('vk_random_id' => result[:random_id].to_s) if result[:random_id]

    message.update!(update_attrs)
  end

  def inbox
    @inbox ||= message.inbox
  end

  def channel
    @channel ||= inbox.channel
  end
end
