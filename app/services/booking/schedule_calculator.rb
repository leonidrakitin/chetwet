# frozen_string_literal: true

class Booking::ScheduleCalculator
  def initialize(schedule, date)
    @schedule = schedule
    @date = date
  end

  def call
    return [] unless @schedule

    day_name = day_name_from_wday(@date.wday)
    day_config = @schedule.working_hours_for(day_name)

    return [] unless day_config['enabled']

    slots = []
    day_config['slots'].each do |slot_config|
      slots.concat(generate_slots_for_range(slot_config))
    end

    apply_breaks(slots)
  end

  private

  def generate_slots_for_range(slot_config)
    start_time = parse_time(slot_config['start'])
    end_time = parse_time(slot_config['end'])

    slots = []
    current = start_time

    while current < end_time
      slots << current.strftime('%H:%M')
      current += @schedule.slot_interval_minutes.minutes
    end

    slots
  end

  def apply_breaks(slots)
    return slots if @schedule.breaks.empty?

    breaks = @schedule.breaks.map do |break_config|
      {
        start: parse_time(break_config['start']),
        end: parse_time(break_config['end'])
      }
    end

    slots.reject do |slot|
      slot_time = parse_time(slot)
      breaks.any? do |brk|
        slot_time >= brk[:start] && slot_time < brk[:end]
      end
    end
  end

  def parse_time(time_str)
    hour, minute = time_str.to_s.split(':').map(&:to_i)
    @schedule.tz.local(@date.year, @date.month, @date.day, hour, minute)
  end

  def day_name_from_wday(wday)
    %w[sunday monday tuesday wednesday thursday friday saturday][wday]
  end
end
