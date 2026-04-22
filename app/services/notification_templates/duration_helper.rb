module NotificationTemplates::DurationHelper
  UNIT_SECONDS = {
    'minutes' => 60,
    'hours' => 3_600,
    'days' => 86_400,
    'weeks' => 604_800,
    'months' => 2_592_000
  }.freeze

  module_function

  def duration(value, unit)
    seconds = UNIT_SECONDS[unit.to_s]
    return nil if seconds.blank? || value.to_i <= 0

    value.to_i * seconds
  end

  def interval_duration(conditions)
    conditions ||= {}
    value = conditions['interval_value']
    unit = conditions['interval_unit']

    if value.blank? && conditions['interval_days'].to_i.positive?
      value = conditions['interval_days']
      unit = 'days'
    end

    duration(value, unit)
  end

  def min_interval_duration(limits)
    limits ||= {}
    value = limits['min_interval_value']
    unit = limits['min_interval_unit']

    if value.blank? && limits['min_interval_hours'].to_i.positive?
      value = limits['min_interval_hours']
      unit = 'hours'
    end

    duration(value, unit)
  end
end
