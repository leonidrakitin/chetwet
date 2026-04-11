# frozen_string_literal: true

require_relative 'base_tool'

class Captain::Tools::BookingGetAvailableSlotsTool < BaseTool
  description 'Get available time slots for booking on a specific date'
  param :provider_id, type: 'string', desc: 'Service provider ID (required)'
  param :service_ids, type: 'string', desc: 'Comma-separated service IDs (required)'
  param :date, type: 'string', desc: 'Date in YYYY-MM-DD format (required)'

  def perform(_tool_context, provider_id:, service_ids:, date:)
    return error_result('Account has no schedule configured') unless @account.service_schedule

    slots = Booking::AvailabilityService.new(
      account: @account,
      provider_id: provider_id,
      service_ids: service_ids,
      date: date
    ).call

    if slots.empty?
      format_result("No available slots for #{date}")
    else
      format_result("Available slots for #{date}: #{slots.join(', ')}", data: { slots: slots, date: date })
    end
  rescue ActiveRecord::RecordNotFound => e
    error_result("Provider or service not found: #{e.message}")
  rescue Date::Error => e
    error_result("Invalid date format: #{e.message}")
  end
end
