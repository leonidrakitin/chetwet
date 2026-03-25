class Captain::AutoClassifyConversationJob < ApplicationJob
  queue_as :low

  def perform(conversation_id:, assistant_id: nil)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation

    assistant = assistant_id ? Captain::Assistant.find_by(id: assistant_id) : nil

    classifier = Captain::AutoClassificationService.new(
      conversation: conversation,
      assistant: assistant
    )

    classification = classifier.classify
    return unless classification

    apply_classification(conversation, classification)

    log_classification(conversation, classification)
  rescue StandardError => e
    Rails.logger.error "[Captain AutoClassify] Job error for conversation #{conversation_id}: #{e.message}"
    Sentry.capture_exception(e, extra: { conversation_id: conversation_id })
  end

  private

  def apply_classification(conversation, classification)
    # Apply department as label if present
    if classification[:department].present?
      label = Label.find_or_create_by(
        account_id: conversation.account_id,
        name: "department:#{classification[:department]}"
      )
      conversation.add_labels([label.id]) if label
    end

    # Apply priority
    conversation.update(priority: map_priority_to_level(classification[:priority])) if classification[:priority].present?

    # Apply sentiment as metadata
    if classification[:sentiment].present?
      conversation.additional_attributes ||= {}
      conversation.additional_attributes['classified_sentiment'] = classification[:sentiment]
      conversation.save(validate: false)
    end

    # Apply tags as labels
    tags_to_label(conversation, classification[:tags]) if classification[:tags].is_a?(Array)

    # Store full classification for audit
    store_classification_metadata(conversation, classification)
  end

  def map_priority_to_level(priority_string)
    priority_map = {
      'low' => 'none',
      'medium' => 'medium',
      'high' => 'high',
      'urgent' => 'urgent'
    }
    priority_map[priority_string] || 'medium'
  end

  def tags_to_label(conversation, tags)
    tags.each do |tag|
      label = Label.find_or_create_by(
        account_id: conversation.account_id,
        name: "tag:#{tag.parameterize}"
      )
      conversation.add_labels([label.id]) if label
    end
  rescue StandardError => e
    Rails.logger.warn "[Captain AutoClassify] Error applying tags: #{e.message}"
  end

  def store_classification_metadata(conversation, classification)
    conversation.additional_attributes ||= {}
    conversation.additional_attributes['auto_classification'] = {
      department: classification[:department],
      priority: classification[:priority],
      sentiment: classification[:sentiment],
      language: classification[:language],
      requires_immediate_response: classification[:requires_immediate_response],
      suggested_template: classification[:suggested_response_template],
      classified_at: Time.current.iso8601
    }
    conversation.save(validate: false)
  end

  def log_classification(conversation, classification)
    Rails.logger.info(
      "[Captain AutoClassify] Classified conversation #{conversation.display_id} " \
      "department=#{classification[:department]} " \
      "priority=#{classification[:priority]} " \
      "sentiment=#{classification[:sentiment]}"
    )
  end
end
