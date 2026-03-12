class NotificationTemplates::ScheduleCalculator
  pattr_initialize [:template!]

  def next_time(from_time: Time.current)
    return unless template.enabled?

    if template.time_template?
      next_time_for_time_template(from_time)
    elsif template.interval_template?
      5.minutes.from_now
    end
  end

  private

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def next_time_for_time_template(from_time)
    send_at = template.schedule['send_at'].presence
    return unless send_at

    cron_time = next_cron_time(send_at, from_time)
    return cron_time if cron_time

    localized_from_time = from_time.in_time_zone(timezone)
    scheduled_time = parse_datetime(send_at)
    return unless scheduled_time

    repeat = template.schedule['repeat'].presence || 'none'
    repeat_until = parse_datetime(template.schedule['repeat_until'])

    candidate = scheduled_time
    candidate = advance_to_future(candidate, localized_from_time, repeat)

    return if repeat_until.present? && candidate.present? && candidate > repeat_until

    candidate&.utc
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def advance_to_future(candidate, localized_from_time, repeat)
    return candidate if repeat == 'none' && candidate >= localized_from_time
    return nil if repeat == 'none'

    candidate = advance_repeat(candidate, repeat) while candidate < localized_from_time
    candidate
  end

  def advance_repeat(candidate, repeat)
    case repeat
    when 'daily'
      candidate + 1.day
    when 'weekly'
      candidate + 1.week
    when 'monthly'
      candidate + 1.month
    else
      candidate
    end
  end

  def next_cron_time(expression, from_time)
    return unless cron_expression?(expression)
    return unless defined?(Fugit)

    parsed = Fugit.parse_cron(expression)
    parsed&.next_time(from_time.in_time_zone(timezone))&.to_timestamptz&.utc
  rescue StandardError
    nil
  end

  def cron_expression?(expression)
    expression.to_s.split.size >= 5
  end

  def parse_datetime(value)
    return if value.blank?

    zone.parse(value.to_s)
  rescue StandardError
    nil
  end

  def timezone
    template.timezone
  end

  def zone
    ActiveSupport::TimeZone[timezone] || Time.zone
  end
end
