# frozen_string_literal: true

class Captain::Tools::BookingUpdateAppointmentTool < Captain::Tools::BookingBaseTool
  description 'Update an existing booking (reschedule, change services or provider)'
  param :booking_id, type: 'string', desc: 'Booking ID to update (required)'
  param :provider_id, type: 'string', desc: 'New service provider ID (optional)', required: false
  param :service_ids, type: 'string', desc: 'Comma-separated service IDs (optional)', required: false
  param :datetime, type: 'string', desc: 'New appointment datetime in YYYY-MM-DD HH:MM format (optional)', required: false
  param :customer_notes, type: 'string', desc: 'Updated customer notes (optional)', required: false
  param :preferences, type: 'object', desc: 'Updated preferences (optional)', required: false

  def perform( # rubocop:disable Metrics/ParameterLists
    tool_context,
    booking_id:,
    provider_id: nil,
    service_ids: nil,
    datetime: nil,
    customer_notes: nil,
    preferences: nil
  )
    contact = contact_for(tool_context)
    booking = account.service_bookings.find_by(id: booking_id)

    return error_result("Booking #{booking_id} not found") unless booking
    return error_result('You can only update your own bookings') if contact && booking.contact_id != contact.id

    params = {}
    params[:service_provider_id] = provider_id if provider_id.present?
    params[:service_ids] = service_ids if service_ids.present?
    params[:scheduled_at] = datetime if datetime.present?
    params[:customer_notes] = customer_notes if customer_notes.present?
    params[:preferences] = preferences if preferences.present?

    updated = Booking::UpdateService.new(booking: booking, params: params).update

    format_result(
      "Booking #{updated.id} updated successfully",
      data: { booking_id: updated.id, scheduled_at: updated.scheduled_at }
    )
  rescue Booking::ConflictChecker::ConflictError => e
    error_result("Time slot conflict: #{e.message}")
  rescue ArgumentError => e
    error_result(e.message)
  rescue ActiveRecord::RecordNotFound => e
    error_result("Provider or service not found: #{e.message}")
  rescue ActiveRecord::RecordInvalid => e
    error_result("Failed to update booking: #{e.message}")
  end
end
