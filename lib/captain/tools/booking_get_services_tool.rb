# frozen_string_literal: true

require_relative 'base_tool'

class Captain::Tools::BookingGetServicesTool < Captain::Tools::BaseTool
  description 'Get list of available services with their durations and prices for booking'
  param :service_name, type: 'string', desc: 'Optional filter by service name (partial match)', required: false

  def perform(_tool_context, service_name: nil)
    services = @account.services.active.ordered

    services = services.where('name ILIKE ?', "%#{service_name}%") if service_name.present?

    return format_result('No services found') if services.empty?

    data = services.limit(20).map do |s|
      {
        id: s.id,
        name: s.name,
        duration_minutes: s.duration_minutes,
        formatted_duration: s.formatted_duration,
        price: s.price&.to_s,
        currency: s.currency
      }
    end

    format_result("Found #{data.size} services", data: data)
  end
end
