class NotificationTemplates::TrackReplyJob < ApplicationJob
  queue_as :low

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return if message.blank? || !message.incoming?

    deliveries = NotificationTemplateDelivery.where(
      conversation_id: message.conversation_id,
      contact_id: message.conversation.contact_id,
      responded_at: nil
    ).where('sent_at < ?', message.created_at)

    deliveries.find_each do |delivery|
      delivery.update!(responded_at: message.created_at, status: 'replied')
    end
  end
end
