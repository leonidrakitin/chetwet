# frozen_string_literal: true

class Captain::Tools::BookingGetProvidersTool < Captain::Tools::BookingBaseTool
  description 'Get list of available service providers (staff members) for booking'

  def perform(_tool_context, **)
    providers = account.service_providers.active.ordered

    return format_result('No providers found') if providers.empty?

    data = providers.map do |provider|
      {
        id: provider.id,
        name: provider.name,
        description: provider.description
      }
    end

    format_result("Found #{data.size} providers", data: data)
  end
end
