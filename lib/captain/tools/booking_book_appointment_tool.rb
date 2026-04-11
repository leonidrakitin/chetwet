# frozen_string_literal: true

require_relative 'base_tool'

class Captain::Tools::BookingBookAppointmentTool < Captain::Tools::BaseTool
  description 'Book an appointment for the contact. Supports multiple services in one booking.'
  param :provider_id, type: 'string', desc: 'Service provider ID (required)'
  param :service_ids, type: 'string', desc: 'Comma-separated service IDs - multiple services supported (required)'
  param :datetime, type: 'string', desc: 'Appointment datetime in YYYY-MM-DD HH:MM format (required)'
  param :customer_notes, type: 'string', desc: 'Optional notes from customer', required: false
  param :preferences, type: 'object', desc: 'Optional preferences (e.g., {"stylist_preference": "male"})', required: false

  def perform(_tool_context, provider_id:, service_ids:, datetime:, customer_notes: nil, preferences: nil) # rubocop:disable Metrics/ParameterLists
    return error_result('No contact associated with this conversation') unless @contact

    booking = Booking::BookingService.new(
      account: @account,
      contact: @contact,
      params: build_params(provider_id, service_ids, datetime, customer_notes, preferences)
    ).book

    format_result(
      "Booking confirmed! ID: #{booking.id}, Time: #{booking.scheduled_at.strftime('%Y-%m-%d %H:%M')}, " \
      "Services: #{booking.services.pluck(:name).join(', ')}",
      data: { booking_id: booking.id, scheduled_at: booking.scheduled_at }
    )
  rescue Booking::ConflictChecker::ConflictError => e
    error_result("Time slot conflict: #{e.message}")
  rescue ArgumentError => e
    error_result(e.message)
  rescue ActiveRecord::RecordNotFound => e
    error_result("Provider or service not found: #{e.message}")
  end

  private

  def build_params(provider_id, service_ids, datetime, customer_notes, preferences)
    {
      service_provider_id: provider_id,
      scheduled_at: DateTime.parse(datetime),
      customer_notes: customer_notes,
      preferences: preferences || {},
      service_booking_items_attributes: service_ids.split(',').map(&:strip).map.with_index do |sid, idx|
        { service_id: sid, position: idx }
      end
    }
  end
end
