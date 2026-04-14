# frozen_string_literal: true

class Vk::SendOnVkService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Vk
  end

  def perform_reply
    vk_random_id = ensure_vk_random_id!
    result = channel.send_message_on_vk(message, random_id: vk_random_id)
    return unless result

    update_attrs = { source_id: result[:message_id].to_s }
    update_attrs[:external_source_ids] = merge_external_source_ids('vk_random_id' => (result[:random_id] || vk_random_id).to_s)

    message.update!(update_attrs)
  end

  def ensure_vk_random_id!
    existing_random_id = message.external_source_ids&.dig('vk_random_id')
    return existing_random_id.to_i if existing_random_id.present?

    random_id = SecureRandom.random_number(2**31)
    message.update!(external_source_ids: merge_external_source_ids('vk_random_id' => random_id.to_s))
    random_id
  end

  def merge_external_source_ids(attrs)
    (message.external_source_ids || {}).merge(attrs)
  end

  def inbox
    @inbox ||= message.inbox
  end

  def channel
    @channel ||= inbox.channel
  end
end
