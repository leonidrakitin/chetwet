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
    ChatwootExceptionTracker.new(e, account: conversation&.account).capture_exception
  end

  private

  def apply_classification(conversation, classification)
    apply_department_label(conversation, classification[:department])
    apply_priority(conversation, classification[:priority])
    apply_tag_labels(conversation, classification[:tags])
    store_classification_metadata(conversation, classification)
  end

  def apply_department_label(conversation, department)
    return if department.blank?

    label_title = "department-#{department}"
    Label.find_or_create_by(account_id: conversation.account_id, title: label_title)
    conversation.add_labels([label_title])
  rescue StandardError => e
    Rails.logger.warn "[Captain AutoClassify] Error applying department label: #{e.message}"
  end

  def apply_priority(conversation, priority)
    return if priority.blank?

    mapped = map_priority(priority)
    conversation.update(priority: mapped) if mapped
  end

  def map_priority(priority_string)
    # Conversation enum: { low: 0, medium: 1, high: 2, urgent: 3 }
    valid = { 'low' => 'low', 'medium' => 'medium', 'high' => 'high', 'urgent' => 'urgent' }
    valid[priority_string]
  end

  def apply_tag_labels(conversation, tags)
    return unless tags.is_a?(Array)

    tags.each do |tag|
      label_title = "tag-#{tag.parameterize}"
      Label.find_or_create_by(account_id: conversation.account_id, title: label_title)
      conversation.add_labels([label_title])
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
