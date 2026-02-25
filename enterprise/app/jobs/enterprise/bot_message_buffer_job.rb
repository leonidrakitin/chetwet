module Enterprise::BotMessageBufferJob
  def dispatch_to_captain(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation&.pending?

    assistant = conversation.inbox.captain_assistant
    return unless assistant

    Captain::Conversation::ResponseBuilderJob.perform_later(conversation, assistant)
  end
end
