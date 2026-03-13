# frozen_string_literal: true

class Captain::Tools::VkMarketBaseTool < Captain::Tools::BasePublicTool
  VK_API_VERSION = '5.199'

  def active?
    assistant_account.inboxes.joins(:channel_vk).exists?
  end

  private

  def vk_channel(state)
    inbox_id = state&.dig(:conversation, :inbox_id)
    return nil unless inbox_id

    inbox = account_scoped(Inbox).find_by(id: inbox_id)
    return nil unless inbox&.channel_type == 'Channel::Vk'

    inbox.channel
  end

  def owner_id(channel)
    "-#{channel.group_id}"
  end

  def vk_api_call(method, channel, params = {})
    response = HTTParty.get(
      "#{channel.vk_api_url}/#{method}",
      query: params.merge(access_token: channel.access_token, v: VK_API_VERSION)
    )
    return { 'error' => 'VK API request failed' } unless response.success?

    parsed = response.parsed_response
    if (error = parsed['error'])
      return { 'error' => "VK API error #{error['error_code']}: #{error['error_msg']}" }
    end

    parsed['response']
  end

  def format_product(item)
    parts = []
    parts << "[#{item['id']}] #{item['title']}"
    parts << "  Price: #{item.dig('price', 'text')}" if item.dig('price', 'text').present?
    parts << "  #{item['description'].truncate(100)}" if item['description'].present?
    availability = case item['availability']
                   when 0 then 'Available'
                   when 1 then 'Removed'
                   when 2 then 'Unavailable'
                   end
    parts << "  Status: #{availability}" if availability
    parts.join("\n")
  end

  def missing_channel_message
    'This tool requires a VK channel. The current conversation is not from a VK inbox.'
  end

  def assistant_account
    @assistant_account ||= Account.find(@assistant.account_id)
  end
end
