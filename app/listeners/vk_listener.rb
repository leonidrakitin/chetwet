# frozen_string_literal: true

class VkListener < BaseListener
  def conversation_typing_on(event)
    conversation = event.data[:conversation]
    user = event.data[:user]

    return unless vk_conversation?(conversation)
    return unless agent_typing?(user)
    return if event.data[:is_private]

    peer_id = conversation.additional_attributes&.dig('peer_id')
    return unless peer_id

    conversation.inbox.channel.send_typing_activity(peer_id)
  rescue StandardError => e
    Rails.logger.error "[VK] VkListener typing error: #{e.message}"
  end

  private

  def vk_conversation?(conversation)
    conversation.inbox.channel_type == 'Channel::Vk'
  end

  def agent_typing?(user)
    user.is_a?(User)
  end
end
