class Campaigns::MessageSenderService
  pattr_initialize [:campaign!, :conversation!]

  def call
    context = NotificationTemplates::ContextBuilder.new(conversation: conversation).call
    conversation.with_lock do
      campaign.messages.each do |message_block|
        message = build_message(message_block, context)
        create_delivery!(message)
      end
    end
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
    create_failed_delivery!(e.message)
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
        campaign_id: campaign.id,
        buttons: message_block['buttons'],
        attachments: message_block['attachments']
      }
    )

    Messages::MessageBuilder.new(nil, conversation, params).perform
  end

  def create_delivery!(message)
    campaign.deliveries.create!(
      account: campaign.account,
      contact: conversation.contact,
      conversation: conversation,
      status: 'sent',
      trigger_type: 'campaign',
      sent_at: Time.current,
      metadata: { message_id: message.id }
    )
  end

  def create_failed_delivery!(error_message)
    campaign.deliveries.create!(
      account: campaign.account,
      contact: conversation.contact,
      conversation: conversation,
      status: 'failed',
      trigger_type: 'campaign',
      sent_at: Time.current,
      metadata: { error: error_message }
    )
  end
end
