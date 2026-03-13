# frozen_string_literal: true

class Captain::Tools::VkMarketSearchProductsTool < Captain::Tools::VkMarketBaseTool
  description 'Search products in VK community market by query'
  param :query, type: 'string', desc: 'Search query text (required)', required: true
  param :count, type: 'integer', desc: 'Number of results to return (default 10, max 30)'

  def perform(tool_context, query:, count: 10, **)
    channel = vk_channel(tool_context.state)
    return missing_channel_message if channel.blank?

    count = [[count.to_i, 1].max, 30].min
    result = vk_api_call('market.search', channel, owner_id: owner_id(channel), q: query, count: count)
    return result['error'] if result.is_a?(Hash) && result['error']

    items = result['items']
    return "No products found matching '#{query}'." if items.blank?

    lines = items.map { |item| format_product(item) }
    "Search results for '#{query}' (#{result['count']} total, showing #{items.size}):\n#{lines.join("\n\n")}"
  rescue StandardError => e
    "VK Market API error: #{e.message}"
  end
end
