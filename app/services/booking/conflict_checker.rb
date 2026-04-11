# frozen_string_literal: true

class Booking::ConflictChecker
  class ConflictError < StandardError; end

  def initialize(booking)
    @booking = booking
  end

  def check!
    conflicts = find_conflicts

    return if conflicts.empty?

    raise ConflictError,
          "Time slot conflicts with existing bookings: #{conflicts.map(&:id).join(', ')}"
  end

  private

  def find_conflicts
    return [] if @booking.scheduled_at.blank?

    @booking.account.service_bookings
            .active_bookings
            .for_provider(@booking.service_provider_id)
            .where.not(id: @booking.id)
            .select do |existing|
      ranges_overlap?(@booking.time_range, existing.time_range)
    end
  end

  def ranges_overlap?(range1, range2)
    range1.begin < range2.end && range2.begin < range1.end
  end
end
