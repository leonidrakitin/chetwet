class NotificationTemplates::DispatchService
  pattr_initialize [:template!, :conversation, :trigger_type]

  def call
    target_conversations.each do |target_conversation|
      next unless due_for_dispatch?(target_conversation)

      eligibility = NotificationTemplates::EligibilityService.new(
        template: template,
        conversation: target_conversation
      ).call

      next unless eligibility[:ok]

      NotificationTemplates::MessageSenderService.new(
        template: template,
        conversation: target_conversation,
        trigger_type: trigger_type
      ).call
    end
  end

  private

  def target_conversations
    Array.wrap(conversation.presence || NotificationTemplates::AudienceScope.new(template: template).call)
  end

  def due_for_dispatch?(target_conversation)
    return true if trigger_type.to_s.start_with?('event:')
    return interval_due?(target_conversation) if template.interval_template?

    true
  end

  def interval_due?(target_conversation)
    reference_time = reference_time_for(target_conversation)
    return false if reference_time.blank?

    interval_days = template.conditions['interval_days'].to_i
    return false if interval_days <= 0

    reference_time <= interval_days.days.ago
  end

  def reference_time_for(target_conversation)
    since = template.conditions['since'].presence || default_since

    case since
    when 'last_visit'
      parse_time(target_conversation.additional_attributes.dig('yclients', 'record_date'))
    when 'registration_date'
      target_conversation.contact.created_at
    else
      target_conversation.messages.chat.last&.created_at || target_conversation.updated_at
    end
  end

  def default_since
    return 'last_visit' if template.template_type == 'lost_clients'

    'last_message'
  end

  def parse_time(value)
    return if value.blank?

    Time.zone.parse(value.to_s)
  rescue StandardError
    nil
  end
end
