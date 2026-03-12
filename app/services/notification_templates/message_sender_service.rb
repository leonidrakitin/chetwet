class NotificationTemplates::MessageSenderService
  pattr_initialize [:template!, :conversation!, :trigger_type]

  def call
    context = NotificationTemplates::ContextBuilder.new(conversation: conversation).call
    conversation.with_lock do
      template.messages.each do |message_block|
        message = build_message(message_block, context)
        create_delivery!(message)
      end
    end

    template.update!(last_sent_at: Time.current, next_send_at: next_send_at)
  end

  private

  def build_message(message_block, context)
    content = NotificationTemplates::ContentRenderer.new(
      content: message_block['text'],
      context: context
    ).call

    params = ActionController::Parameters.new(
      content: content,
      message_type: 'outgoing',
      content_type: 'text',
      content_attributes: {
        notification_template_id: template.id,
        buttons: message_block['buttons'],
        attachments: message_block['attachments']
      }
    )

    Messages::MessageBuilder.new(sender, conversation, params).perform
  end

  def create_delivery!(message)
    template.deliveries.create!(
      account: template.account,
      contact: conversation.contact,
      conversation: conversation,
      status: 'sent',
      trigger_type: trigger_type,
      sent_at: Time.current,
      metadata: { message_id: message.id }
    )
  end

  def next_send_at
    NotificationTemplates::ScheduleCalculator.new(template: template).next_time(from_time: 1.second.from_now)
  end

  def sender
    @sender ||= template.account.users.first
  end
end
