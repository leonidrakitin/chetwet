class CopilotDebugEnricher
  def initialize(copilot_thread)
    @copilot_thread = copilot_thread
  end

  def to_h
    {
      thread: thread_data,
      conversation: conversation_data,
      messages: messages_data,
      tools_used: tools_used_data,
      notification_templates: notification_templates_data
    }
  end

  private

  def thread_data
    {
      id: @copilot_thread.id,
      title: @copilot_thread.title,
      created_at: @copilot_thread.created_at.to_fs(:iso8601)
    }
  end

  def conversation_data
    conversation = @copilot_thread.account.conversations.find_by(copilot_thread_id: @copilot_thread.id)
    return nil unless conversation

    {
      id: conversation.display_id,
      status: conversation.status,
      priority: conversation.priority,
      contact_id: conversation.contact_id,
      created_at: conversation.created_at.to_fs(:iso8601)
    }
  end

  def messages_data
    @copilot_thread.copilot_messages.includes(:copilot_thread).order(created_at: :asc).map do |msg|
      {
        id: msg.id,
        message_type: msg.message_type,
        message: msg.message,
        created_at: msg.created_at.to_fs(:iso8601),
        reasoning: msg.message['reasoning'],
        function_name: msg.message['function_name'],
        reply_suggestion: msg.message['reply_suggestion']
      }
    end
  end

  def tools_used_data
    messages = @copilot_thread.copilot_messages.where("message->>'function_name' IS NOT NULL")
    messages.pluck(Arel.sql("message->>'function_name'")).uniq.compact.map { |name| name.to_s.underscore.tr('_', ' ').titleize }
  end

  def notification_templates_data
    # Check for notification template usage in messages
    messages = @copilot_thread.copilot_messages
    templates = []

    messages.each do |msg|
      content = msg.message['content'] || ''
      if content.include?('notification_template') && content.include?('template')
        # Extract template name from content (simple heuristic)
        templates << { name: 'Notification Template', used: true }
      end
    end

    templates.uniq
  end
end
