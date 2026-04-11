json.extract! booking, :id, :scheduled_at, :total_duration_minutes, :status, :customer_notes,
                    :internal_notes, :preferences, :cancelled_at, :cancellation_reason,
                    :created_at, :updated_at

json.end_time booking.end_time

json.contact do
  json.id booking.contact.id
  json.name booking.contact_name
  json.email booking.contact&.email
  json.phone_number booking.contact&.phone_number
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
