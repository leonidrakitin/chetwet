# frozen_string_literal: true

class Captain::Tools::YclientsGetServicesTool < Captain::Tools::YclientsBaseTool
  description 'Get list of available services and staff from YClients'
  param :company_id, type: 'string', desc: 'Salon/company ID when multiple YClients hooks are connected'

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def perform(tool_context, company_id: nil, **)
    hook = yclients_hook(state: tool_context.state, company_id: company_id)
    return missing_hook_message if hook.blank?

    services = booking_client_for(hook).get_services
    staff = booking_client_for(hook).get_staff

    parts = []
    resolved_company_id = Crm::Yclients::HookResolver.company_id_for(hook)

    if services.present?
      service_lines = services.first(30).map do |s|
        price = s['price_min'] || s['price']
        duration = s['duration']
        "- [#{s['id']}] #{s['title']}#{price ? " (#{price} rub)" : ''}#{duration ? ", #{duration} min" : ''}"
      end
      parts << "Services for company #{resolved_company_id} (#{services.size}):\n#{service_lines.join("\n")}"
    else
      parts << 'No services found'
    end

    if staff.present?
      staff_lines = staff.first(20).map do |s|
        "- [#{s['id']}] #{s['name']}#{s['specialization'].present? ? " - #{s['specialization']}" : ''}"
      end
      parts << "\nStaff (#{staff.size}):\n#{staff_lines.join("\n")}"
    else
      parts << 'No staff found'
    end

    parts.join("\n")
  rescue Crm::Yclients::Api::BaseClient::ApiError => e
    "YClients API error: #{e.message}"
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
end
