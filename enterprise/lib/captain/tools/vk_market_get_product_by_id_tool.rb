# frozen_string_literal: true

class Captain::Tools::VkMarketGetProductByIdTool < Captain::Tools::VkMarketBaseTool
  description 'Get detailed product information from VK market by product ID'
  param :product_id, type: 'string', desc: 'Product ID (required)', required: true

  def perform(tool_context, product_id:, **)
    channel = vk_channel(tool_context.state)
    return missing_channel_message if channel.blank?

    item_id = "#{owner_id(channel)}_#{product_id}"
    result = vk_api_call('market.getById', channel, item_ids: item_id, extended: 1)
    return result['error'] if result.is_a?(Hash) && result['error']

    items = result['items']
    return "Product #{product_id} not found." if items.blank?

    format_product_details(items.first)
  rescue StandardError => e
    "VK Market API error: #{e.message}"
  end

  private

  def format_product_details(item)
    parts = []
    parts << "Product ##{item['id']}: #{item['title']}"
    parts << "Price: #{item.dig('price', 'text')}" if item.dig('price', 'text').present?
    parts << "Description: #{item['description']}" if item['description'].present?
    parts << "Category: #{item.dig('category', 'name')}" if item.dig('category', 'name').present?
    parts << "URL: #{item['url']}" if item['url'].present?
    availability = case item['availability']
                   when 0 then 'Available'
                   when 1 then 'Removed'
                   when 2 then 'Unavailable'
                   end
    parts << "Status: #{availability}" if availability
    parts << "Likes: #{item.dig('likes', 'count')}" if item.dig('likes', 'count')
    parts.join("\n")
  end
end
