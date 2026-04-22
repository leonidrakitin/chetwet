class NotificationTemplates::DispatchService
  pattr_initialize [:template!, :conversation, :trigger_type]

  RESCHEDULABLE_REASONS = %w[quiet_hours active_dialog stop_if_replied max_per_day per_contact_gap min_interval].freeze

  def call
    target_conversations.each do |target_conversation|
      next unless due_for_dispatch?(target_conversation)

      eligibility = NotificationTemplates::EligibilityService.new(
        template: template,
        conversation: target_conversation
      ).call

      if eligibility[:ok]
        NotificationTemplates::MessageSenderService.new(
          template: template,
          conversation: target_conversation,
          trigger_type: trigger_type
        ).call
      elsif RESCHEDULABLE_REASONS.include?(eligibility[:reason])
        enqueue_scheduled_delivery(target_conversation, eligibility[:reason])
      end
    end
  end

  private

  def enqueue_scheduled_delivery(target_conversation, reason)
    contact = target_conversation.contact
    return if existing_scheduled_for?(contact)

    scheduled_for = NotificationTemplates::SchedulerService.new(
      template: template,
      contact: contact,
      account: template.account,
      reason: reason
    ).call

    template.deliveries.create!(
      account: template.account,
      contact: contact,
      conversation: target_conversation,
      status: 'scheduled',
      trigger_type: trigger_type,
      scheduled_for: scheduled_for,
      metadata: { reason: reason }
    )
  end

  def existing_scheduled_for?(contact)
    template.deliveries.where(contact_id: contact.id, status: 'scheduled').exists?
  end

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

    duration = NotificationTemplates::DurationHelper.interval_duration(template.conditions)
    return false if duration.nil? || duration <= 0

    reference_time <= duration.ago
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
