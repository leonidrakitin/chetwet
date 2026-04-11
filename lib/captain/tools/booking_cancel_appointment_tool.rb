# frozen_string_literal: true

require_relative 'base_tool'

class Captain::Tools::BookingCancelAppointmentTool < BaseTool
  description 'Cancel an existing booking'
  param :booking_id, type: 'string', desc: 'Booking ID to cancel (required)'
  param :reason, type: 'string', desc: 'Cancellation reason (optional)', required: false

  def perform(_tool_context, booking_id:, reason: nil)
    booking = @account.service_bookings.find_by(id: booking_id)

    return error_result("Booking #{booking_id} not found") unless booking

    return error_result('You can only cancel your own bookings') if @contact && booking.contact_id != @contact.id

    booking.cancel!(reason: reason)

    format_result("Booking #{booking_id} cancelled successfully")
  rescue ActiveRecord::RecordInvalid => e
    error_result("Failed to cancel booking: #{e.message}")
  end
end
