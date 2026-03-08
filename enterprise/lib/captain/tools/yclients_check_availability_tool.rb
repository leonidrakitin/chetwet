# frozen_string_literal: true

class Captain::Tools::YclientsCheckAvailabilityTool < Captain::Tools::YclientsBaseTool
  description 'Check available time slots for booking in YClients'
  param :company_id, type: 'string', desc: 'Salon/company ID when multiple YClients hooks are connected'
  param :staff_id, type: 'string', desc: 'Staff member ID (optional, omit to check all)'
  param :date, type: 'string', desc: 'Date in YYYY-MM-DD format (optional, defaults to today)'

  def perform(tool_context, company_id: nil, staff_id: nil, date: nil)
    hook = yclients_hook(state: tool_context.state, company_id: company_id)
    return missing_hook_message if hook.blank?

    date ||= Date.current.to_s

    if staff_id.present?
      slots = booking_client_for(hook).get_times(staff_id, date)
      return "No available slots for staff #{staff_id} on #{date}" if slots.blank?

      format_time_slots(slots, date, Crm::Yclients::HookResolver.company_id_for(hook))
    else
      dates = booking_client_for(hook).get_dates
      return 'No available dates found' if dates.blank?

      format_available_dates(dates, Crm::Yclients::HookResolver.company_id_for(hook))
    end
  rescue Crm::Yclients::Api::BaseClient::ApiError => e
    "YClients API error: #{e.message}"
  end

  private

  def format_time_slots(slots, date, company_id)
    lines = slots.first(30).map do |slot|
      time = slot['time'] || slot['datetime']
      "- #{time}"
    end

    "Available slots for company #{company_id} on #{date}:\n#{lines.join("\n")}"
  end

  def format_available_dates(dates, company_id)
    lines = dates.first(14).map { |d| "- #{d['date'] || d}" }
    "Available dates for company #{company_id}:\n#{lines.join("\n")}"
  end
end
