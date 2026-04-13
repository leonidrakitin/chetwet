# frozen_string_literal: true

json.schedule do
  if @schedule
    json.partial! 'api/v1/accounts/services/schedule', schedule: @schedule
  else
    json.nil!
  end
end

json.providers @providers do |provider|
  json.id provider.id
  json.name provider.name
  json.active provider.active
end

json.date_range do
  json.start_date @date_range.begin.iso8601
  json.end_date @date_range.end.iso8601
end

contact_ids = @bookings.map(&:contact_id).uniq
contact_booking_counts = ServiceBooking.where(contact_id: contact_ids).group(:contact_id).count

json.bookings @bookings do |booking|
  json.extract! booking, :id, :scheduled_at, :total_duration_minutes, :status,
                        :customer_notes, :internal_notes, :cancelled_at, :cancellation_reason

  json.end_time booking.end_time

  json.contact do
    json.id booking.contact.id
    json.name booking.contact_name
    json.phone_number booking.contact&.phone_number
    json.email booking.contact&.email
    json.is_first_booking contact_booking_counts[booking.contact_id] == 1
  end

  json.service_provider do
    json.id booking.service_provider.id
    json.name booking.service_provider_name
  end

  json.services booking.service_booking_items do |item|
    json.id item.service_id
    json.name item.service_name
    json.position item.position
    json.duration_minutes item.duration_minutes
    json.price item.price
  end
end
