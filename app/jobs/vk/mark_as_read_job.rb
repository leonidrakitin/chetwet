# frozen_string_literal: true

class Vk::MarkAsReadJob < ApplicationJob
  queue_as :low

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation

    channel = conversation.inbox&.channel
    return unless channel.is_a?(Channel::Vk)

    peer_id = conversation.additional_attributes&.dig('peer_id')
    return unless peer_id

    channel.mark_as_read(peer_id)
  rescue StandardError => e
    Rails.logger.error "[VK] MarkAsReadJob error: #{e.message}"
  end
end
