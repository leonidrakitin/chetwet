class NotificationTemplateListener < BaseListener
  def conversation_created(event)
    dispatch_default_templates(event.data[:conversation], 'conversation_created')
  end

  def conversation_resolved(event)
    dispatch_default_templates(event.data[:conversation], 'conversation_resolved')
  end

  def message_created(event)
    message = event.data[:message]
    return if message.blank?
    return unless message.incoming?

    NotificationTemplates::TrackReplyJob.perform_later(message.id)
    dispatch_default_templates(message.conversation, 'message_received')
  end

  private

  def dispatch_default_templates(conversation, event_type)
    return if conversation.blank?

    conversation.account.notification_templates
                .active
                .where(template_type: 'event', event_type: event_type)
                .find_each do |template|
      NotificationTemplates::DispatchJob.perform_later(template.id, conversation.id, "event:#{event_type}")
    end
  end
end
