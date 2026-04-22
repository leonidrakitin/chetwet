# frozen_string_literal: true

class Captain::Tools::YclientsUpdateVisitStatusTool < Captain::Tools::YclientsBaseTool
  risk_level :write

  description 'Update attendance status of a YClients appointment (visit)'
  param :visit_id, type: 'string', desc: 'Visit ID from the appointment record (required)'
  param :record_id, type: 'string', desc: 'Record ID of the appointment (required)'
  param :attendance, type: 'string', desc: 'New status: visited, confirmed, cancelled, or pending (required)'
  param :company_id, type: 'string', desc: 'Salon/company ID when multiple YClients hooks are connected'

  ATTENDANCE_MAP = {
    'visited' => 1,
    'confirmed' => 2,
    'cancelled' => -1,
    'pending' => 0
  }.freeze

  def perform(tool_context, visit_id:, record_id:, attendance:, company_id: nil)
    grounding_error = ensure_prior_tool(tool_context, :yclients_get_transactions)
    return grounding_error[:error] if grounding_error

    hook = yclients_hook(state: tool_context.state, company_id: company_id)
    return missing_hook_message if hook.blank?

    code = ATTENDANCE_MAP[attendance.to_s.downcase]
    return "Invalid attendance value: #{attendance}. Use: visited, confirmed, cancelled, or pending" if code.nil?

    visits_client_for(hook).update_status(visit_id, record_id, { 'attendance' => code })

    "Visit status updated to '#{attendance}' for record #{record_id}"
  rescue Crm::Yclients::Api::BaseClient::ApiError => e
    "Failed to update visit status: #{e.message}"
  end
end
