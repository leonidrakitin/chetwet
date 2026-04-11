# frozen_string_literal: true

require_relative 'base_tool'

class Captain::Tools::BookingGetProvidersTool < BaseTool
  description 'Get list of available service providers (staff members) for booking'

  def perform(_tool_context, **)
    providers = @account.service_providers.active.ordered

    return format_result('No providers found') if providers.empty?

    data = providers.map do |p|
      {
        id: p.id,
        name: p.name,
        description: p.description
      }
    end

    format_result("Found #{data.size} providers", data: data)
  end
end
