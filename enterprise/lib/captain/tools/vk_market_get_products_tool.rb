# frozen_string_literal: true

class Captain::Tools::VkMarketGetProductsTool < Captain::Tools::VkMarketBaseTool
  description 'Get list of products from VK community market'
  param :count, type: 'integer', desc: 'Number of products to return (default 10, max 30)'
  param :offset, type: 'integer', desc: 'Offset for pagination (default 0)'

  def perform(tool_context, count: 10, offset: 0, **)
    channel = vk_channel(tool_context.state)
    return missing_channel_message if channel.blank?

    count = [[count.to_i, 1].max, 30].min
    result = vk_api_call('market.get', channel, owner_id: owner_id(channel), count: count, offset: offset.to_i)
    return result['error'] if result.is_a?(Hash) && result['error']

    items = result['items']
    return 'No products found in this market.' if items.blank?

    lines = items.map { |item| format_product(item) }
    "Products (#{result['count']} total, showing #{items.size}):\n#{lines.join("\n\n")}"
  rescue StandardError => e
    "VK Market API error: #{e.message}"
  end
end
