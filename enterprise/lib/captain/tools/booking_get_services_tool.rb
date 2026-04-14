# frozen_string_literal: true

class Captain::Tools::BookingGetServicesTool < Captain::Tools::BookingBaseTool
  description 'Get list of available services with their durations and prices for booking'
  param :service_name, type: 'string', desc: 'Optional filter by service name (partial match)', required: false

  def perform(_tool_context, service_name: nil)
    services = account.services.active.ordered

    services = services.where('name ILIKE ?', "%#{service_name}%") if service_name.present?

    return format_result('No services found') if services.empty?

    data = services.limit(20).map do |service|
      {
        id: service.id,
        name: service.name,
        duration_minutes: service.duration_minutes,
        formatted_duration: service.formatted_duration,
        price: service.price&.to_s,
        currency: service.currency
      }
    end

    format_result("Found #{data.size} services", data: data)
  end
end
