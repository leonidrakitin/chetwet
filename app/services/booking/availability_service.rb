# frozen_string_literal: true

class Booking::AvailabilityService
  def initialize(account:, provider_id:, service_ids:, date:)
    @account = account
    @provider = account.service_providers.find(provider_id)
    @services = account.services.where(id: service_ids.to_s.split(',').map(&:strip))
    @date = date.to_date
    @schedule = account.service_schedule
  end

  def call
    return [] unless @schedule
    return [] if @schedule.holiday?(@date)

    total_duration = @services.sum(:duration_minutes)
    working_slots = calculate_working_slots
    booked_slots = get_booked_slots

    available_slots = subtract_booked_slots(working_slots, booked_slots)
    filter_by_duration(available_slots, total_duration)
  end

  private

  def calculate_working_slots
    ScheduleCalculator.new(@schedule, @date).call
  end

  def get_booked_slots
    @provider.service_bookings
             .active_bookings
             .on_date(@date)
             .map do |booking|
      {
        start: booking.scheduled_at,
        end: booking.end_time
      }
    end
  end

  def subtract_booked_slots(working, booked)
    return working if booked.empty?

    available = working.dup

    booked.each do |booked_slot|
      available.reject! do |slot|
        slot_time = parse_slot_time(slot)
        slot_end = slot_time + @schedule.slot_interval_minutes.minutes
        ranges_overlap?(slot_time..slot_end, booked_slot[:start]..booked_slot[:end])
      end
    end

    available
  end

  def filter_by_duration(slots, required_duration)
    return [] if slots.empty?

    slots_count = (required_duration.to_f / @schedule.slot_interval_minutes).ceil
    interval_seconds = @schedule.slot_interval_minutes * 60

    slots.each_index.select do |i|
      next false if i + slots_count > slots.length

      consecutive = slots[i, slots_count]
      next false if consecutive.length < slots_count

      consecutive.each_cons(2).all? do |s1, s2|
        t1 = parse_slot_time(s1)
        t2 = parse_slot_time(s2)
        (t2 - t1).to_i == interval_seconds
      end
    end.map { |i| slots[i] }
  end

  def parse_slot_time(slot)
    if slot.is_a?(Time) || slot.is_a?(ActiveSupport::TimeWithZone)
      slot
    else
      hour, minute = slot.split(':').map(&:to_i)
      @schedule.tz.local(@date.year, @date.month, @date.day, hour, minute)
    end
  end

  def ranges_overlap?(range1, range2)
    range1.begin < range2.end && range2.begin < range1.end
  end
end
