# frozen_string_literal: true

class Captain::Tools::YclientsBookAppointmentTool < Captain::Tools::YclientsBaseTool
  description 'Book an appointment in YClients for the current contact'
  param :company_id, type: 'string', desc: 'Salon/company ID when multiple YClients hooks are connected'
  param :staff_id, type: 'string', desc: 'Staff member ID (required)'
  param :service_ids, type: 'string', desc: 'Comma-separated service IDs (required)'
  param :datetime, type: 'string', desc: 'Appointment datetime in YYYY-MM-DD HH:MM format (required)'

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def perform(tool_context, staff_id:, service_ids:, datetime:, company_id: nil)
    hook = yclients_hook(state: tool_context.state, company_id: company_id)
    return missing_hook_message if hook.blank?

    contact = find_contact(tool_context.state)
    return 'Contact not found' if contact.blank?
    return 'Contact name is required to book an appointment' if contact.name.blank?
    return 'Contact phone number is required to book an appointment' if contact.phone_number.blank?
    return 'Contact email is required to book an appointment' if contact.email.blank?

    yclients_id = ensure_yclients_client_id(tool_context.state, hook: hook)
    return 'Contact is not linked to a YClients client' unless yclients_id

    services = service_ids.split(',').map(&:strip).map(&:to_i).reject(&:zero?)
    return 'At least one valid service ID is required' if services.blank?

    booking_data = {
      'phone' => contact.phone_number,
      'fullname' => contact.name,
      'email' => contact.email,
      'comment' => "Booked from Chatwoot conversation ##{tool_context.state&.dig(:conversation,
                                                                                 :display_id) || tool_context.state&.dig(:conversation,
                                                                                                                         'display_id')}",
      'appointments' => [
        {
          'id' => 1,
          'services' => services,
          'staff_id' => staff_id.to_i,
          'datetime' => datetime
        }
      ]
    }

    booking_client_for(hook).check_booking(
      'appointments' => booking_data['appointments']
    )

    result = booking_client_for(hook).create_booking(booking_data)
    record_payload = result.is_a?(Array) ? result.first : result
    record_id = record_payload&.dig('record_id') || record_payload&.dig('id')

    if record_id
      "Appointment booked successfully in company #{Crm::Yclients::HookResolver.company_id_for(hook)} (Record ID: #{record_id}) for #{datetime}"
    else
      'Appointment created but no record ID returned'
    end
  rescue Crm::Yclients::Api::BaseClient::ApiError => e
    "Failed to book appointment: #{e.message}"
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
end
