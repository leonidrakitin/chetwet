class NotificationTemplates::SchedulerService
  pattr_initialize [:template!, :contact!, :account!, { reason: nil, base_time: nil }]

  MAX_ITERATIONS = 10

  def call
    time = base_time || Time.current
    time = add_retry_delay(time)

    MAX_ITERATIONS.times do
      bumped_quiet = bump_out_of_quiet_hours(time)
      bumped_gap = ensure_contact_gap(bumped_quiet)

      return bumped_gap if bumped_gap == time || bumped_gap == bumped_quiet

      time = bumped_gap
    end

    time
  end

  private

  def global_limits
    @global_limits ||= account.notification_delivery_limits || {}
  end

  def bypass_global?
    template.limits['bypass_global_limits'] == true
  end

  def add_retry_delay(time)
    return time unless reason.to_s == 'stop_if_replied'
    return time if bypass_global?

    minutes = global_limits['stop_if_replied_retry_minutes'].to_i
    minutes.positive? ? time + minutes.minutes : time
  end

  def bump_out_of_quiet_hours(time)
    from = template.limits['quiet_hours_from'].presence
    to = template.limits['quiet_hours_to'].presence
    return time if from.blank? || to.blank?

    tz = template.timezone
    local = time.in_time_zone(tz)
    from_minutes = minutes_for(from)
    to_minutes = minutes_for(to)
    current_minutes = (local.hour * 60) + local.min

    return time unless within_quiet?(current_minutes, from_minutes, to_minutes)

    target = local.change(hour: to_minutes / 60, min: to_minutes % 60, sec: 0)
    # quiet_hours_from > quiet_hours_to => quiet spans midnight; "to" is on next day if current already past midnight it stays same day
    target += 1.day if from_minutes > to_minutes && current_minutes >= from_minutes
    target.utc
  end

  def within_quiet?(current_minutes, from_minutes, to_minutes)
    if from_minutes <= to_minutes
      current_minutes >= from_minutes && current_minutes < to_minutes
    else
      current_minutes >= from_minutes || current_minutes < to_minutes
    end
  end

  def ensure_contact_gap(time)
    gap_minutes = bypass_global? ? 0 : global_limits['per_contact_gap_minutes'].to_i
    return time if gap_minutes <= 0

    neighbor = conflicting_neighbor(time, gap_minutes)
    return time if neighbor.nil?

    neighbor + gap_minutes.minutes
  end

  def conflicting_neighbor(time, gap_minutes)
    window_start = time - gap_minutes.minutes
    window_end = time + gap_minutes.minutes

    scope = account.notification_template_deliveries.where(contact_id: contact.id)
    neighbor_time = scope.where(status: %w[sent replied failed])
                         .where(sent_at: window_start..window_end)
                         .maximum(:sent_at)

    scheduled_neighbor = scope.where(status: 'scheduled')
                              .where(scheduled_for: window_start..window_end)
                              .maximum(:scheduled_for)

    [neighbor_time, scheduled_neighbor].compact.max
  end

  def minutes_for(value)
    hours, minutes = value.to_s.split(':').map(&:to_i)
    (hours * 60) + minutes
  end
end
