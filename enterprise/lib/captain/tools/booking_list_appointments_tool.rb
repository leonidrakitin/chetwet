# frozen_string_literal: true

class Captain::Tools::BookingListAppointmentsTool < Captain::Tools::BookingBaseTool
  description 'List appointments for the current contact'
  param :scope, type: 'string', desc: 'Scope: upcoming, past, all (default upcoming)', required: false
  param :limit, type: 'integer', desc: 'Maximum number of appointments (default 10, max 50)', required: false

  def perform(tool_context, scope: 'upcoming', limit: 10)
    contact = contact_for(tool_context)
    return error_result('No contact associated with this conversation') unless contact

    bookings = account.service_bookings.for_contact(contact.id)
    bookings = filter_scope(bookings, scope)

    limit = [[limit.to_i, 1].max, 50].min
    data = bookings.includes(:services, :service_provider).limit(limit).map do |booking|
      {
        id: booking.id,
        status: booking.status,
        scheduled_at: booking.scheduled_at,
        provider: booking.service_provider&.name,
        services: booking.services.pluck(:name),
        cancellation_reason: booking.cancellation_reason
      }
    end

    return format_result('No bookings found') if data.empty?

    format_result("Found #{data.size} bookings", data: data)
  end

  private

  def filter_scope(bookings, scope)
    case scope
    when 'past'
      bookings.past
    when 'all'
      bookings.order(scheduled_at: :desc)
    else
      bookings.upcoming
    end
  end
end
