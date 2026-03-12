class NotificationTemplates::DispatchJob < ApplicationJob
  queue_as :high

  def perform(template_id, conversation_id = nil, trigger_type = nil)
    template = NotificationTemplate.find(template_id)
    conversation = Conversation.find_by(id: conversation_id) if conversation_id.present?

    NotificationTemplates::DispatchService.new(
      template: template,
      conversation: conversation,
      trigger_type: trigger_type
    ).call
  end
end
