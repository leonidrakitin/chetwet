# frozen_string_literal: true

class Captain::Tools::YclientsLookupClientTool < Captain::Tools::YclientsBaseTool
  description 'Look up client records and appointments in YClients for the current contact'
  param :company_id, type: 'string', desc: 'Salon/company ID when multiple YClients hooks are connected'

  def perform(tool_context, company_id: nil, **)
    hook = yclients_hook(state: tool_context.state, company_id: company_id)
    return missing_hook_message if hook.blank?

    yclients_id = find_yclients_client_id(tool_context.state, hook: hook)
    return 'Contact is not linked to a YClients client' unless yclients_id

    records = records_client_for(hook).get_by_client(yclients_id)
    return 'No records found for this client' if records.blank?

    format_records(records, Crm::Yclients::HookResolver.company_id_for(hook))
  rescue Crm::Yclients::Api::BaseClient::ApiError => e
    "YClients API error: #{e.message}"
  end

  private

  def format_records(records, company_id)
    lines = records.first(20).map do |r|
      date = r['date'] || r['datetime']
      services = Array.wrap(r['services']).map { |s| s['title'] }.join(', ')
      staff = r.dig('staff', 'name') || 'N/A'
      status = attendance_label(r['attendance'])
      "- #{date}: #{services.presence || 'No service'} (Staff: #{staff}, Status: #{status})"
    end

    "Found #{records.size} record(s) for company #{company_id}:\n#{lines.join("\n")}"
  end

  def attendance_label(attendance)
    case attendance.to_i
    when 1 then 'Visited'
    when 2 then 'Confirmed'
    when -1 then 'Cancelled'
    else 'Pending'
    end
  end
end
