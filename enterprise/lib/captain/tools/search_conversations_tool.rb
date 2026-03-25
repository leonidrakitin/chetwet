class Captain::Tools::SearchConversationsTool < Captain::Tools::BasePublicTool
  description 'Search conversations by query text, status, or labels to find related issues'
  param :query, type: 'string', desc: 'Text to search in conversation messages'
  param :status, type: 'string', desc: 'Filter by status: open, resolved, pending (optional)', required: false
  param :label, type: 'string', desc: 'Filter by label name (optional)', required: false

  MAX_RESULTS = 5

  def perform(_tool_context, query:, status: nil, label: nil)
    log_tool_usage('search_conversations', { query: query, status: status, label: label })

    conversations = search(query, status, label)

    if conversations.empty?
      "No conversations found for: #{query}"
    else
      format_results(conversations)
    end
  end

  private

  def search(query, status, label)
    scope = account_scoped(::Conversation).includes(:contact, :labels)
    scope = scope.where(status: status) if status.present?
    scope = scope.tagged_with(label, any: true) if label.present?

    if query.present?
      message_conversation_ids = account_scoped(::Message)
                                 .where('content ILIKE ?', "%#{sanitize_query(query)}%")
                                 .select(:conversation_id)
                                 .distinct
                                 .limit(MAX_RESULTS * 2)
      scope = scope.where(id: message_conversation_ids)
    end

    scope.order(last_activity_at: :desc).limit(MAX_RESULTS).to_a
  end

  def sanitize_query(query)
    query.gsub(/[%_\\]/) { |m| "\\#{m}" }
  end

  def format_results(conversations)
    conversations.map { |c| format_conversation(c) }.join("\n---\n")
  end

  def format_conversation(conversation)
    contact_name = conversation.contact&.name || 'Unknown'
    labels = conversation.label_list.join(', ')

    result = "Conversation ##{conversation.display_id}: #{contact_name} (#{conversation.status})"
    result += "\nLabels: #{labels}" if labels.present?
    result += "\nLast activity: #{conversation.last_activity_at&.strftime('%Y-%m-%d %H:%M')}"
    result
  end
end
