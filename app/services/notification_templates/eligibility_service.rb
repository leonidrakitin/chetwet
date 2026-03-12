class NotificationTemplates::EligibilityService
  pattr_initialize [:template!, :conversation!]

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def call
    return failure('template_disabled') unless template.enabled?
    return failure('blocked_contact') if conversation.contact.blocked?
    return failure('no_contact_inbox') if conversation.contact_inbox.blank?
    return failure('quiet_hours') if within_quiet_hours?
    return failure('active_dialog') if skip_if_has_active_dialog? && active_dialog?
    return failure('stop_if_replied') if stop_if_replied? && replied_after_last_delivery?
    return failure('max_per_day') if max_per_day_reached?
    return failure('min_interval') if min_interval_not_elapsed?

    success
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  private

  def success
    { ok: true }
  end

  def failure(reason)
    { ok: false, reason: reason }
  end

  def deliveries_scope
    template.deliveries.where(contact_id: conversation.contact_id, status: %w[sent replied failed])
  end

  def last_delivery
    @last_delivery ||= deliveries_scope.order(sent_at: :desc).first
  end

  def within_quiet_hours?
    from = template.limits['quiet_hours_from'].presence
    to = template.limits['quiet_hours_to'].presence
    return false if from.blank? || to.blank?

    now = Time.current.in_time_zone(template.timezone)
    from_minutes = minutes_for(from)
    to_minutes = minutes_for(to)
    current_minutes = (now.hour * 60) + now.min

    if from_minutes <= to_minutes
      current_minutes >= from_minutes && current_minutes < to_minutes
    else
      current_minutes >= from_minutes || current_minutes < to_minutes
    end
  end

  def replied_after_last_delivery?
    return false if last_delivery.blank?

    conversation.messages.incoming.exists?(['created_at > ?', last_delivery.sent_at])
  end

  def max_per_day_reached?
    max_per_day = template.limits['max_per_day'].to_i
    return false if max_per_day <= 0

    start_of_day = Time.current.beginning_of_day
    template.account.notification_template_deliveries
            .where(status: %w[sent replied failed])
            .where(contact_id: conversation.contact_id)
            .where('sent_at >= ?', start_of_day)
            .count >= max_per_day
  end

  def min_interval_not_elapsed?
    min_interval_hours = effective_min_interval_hours
    return false if min_interval_hours <= 0 || last_delivery.blank?

    last_delivery.sent_at > min_interval_hours.hours.ago
  end

  def effective_min_interval_hours
    [
      template.limits['min_interval_hours'].to_i,
      24
    ].max
  end

  def stop_if_replied?
    template.limits['stop_if_replied'] == true
  end

  def skip_if_has_active_dialog?
    template.limits['skip_if_has_active_dialog'] == true
  end

  def active_dialog?
    conversation.open? || conversation.pending?
  end

  def minutes_for(value)
    hours, minutes = value.to_s.split(':').map(&:to_i)
    (hours * 60) + minutes
  end
end
