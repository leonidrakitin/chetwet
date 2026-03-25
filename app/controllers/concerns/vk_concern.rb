# frozen_string_literal: true

module VkConcern
  extend ActiveSupport::Concern

  VK_API_VERSION = '5.199'

  def vk_oauth_client
    ::OAuth2::Client.new(
      vk_id_client_id,
      vk_id_client_secret,
      {
        site: 'https://id.vk.com',
        authorize_url: 'https://id.vk.com/authorize',
        token_url: 'https://id.vk.com/oauth2/token',
        auth_scheme: :request_body,
        token_method: :post
      }
    )
  end

  def fetch_vk_groups(access_token, user_id: nil)
    query = { access_token: access_token, filter: 'admin',
              extended: 1, fields: 'photo_50,members_count', v: VK_API_VERSION }
    query[:user_id] = user_id if user_id.present?
    response = HTTParty.get('https://api.vk.com/method/groups.get', query: query)
    return log_and_empty("[VK] groups.get HTTP error: #{response.code} #{response.body}") unless response.success?

    parsed = response.parsed_response
    return log_and_empty("[VK] groups.get API error: #{parsed['error'].inspect}") if parsed['error'].present?

    parsed.dig('response', 'items') || []
  end

  def enable_group_messages(access_token, group_id)
    HTTParty.get(
      'https://api.vk.com/method/groups.setSettings',
      query: {
        group_id: group_id,
        access_token: access_token,
        messages: 1,
        bots_capabilities: 1,
        v: VK_API_VERSION
      }
    )
  end

  def oauth_enabled?
    vk_id_client_id.present? && vk_id_client_secret.present?
  end

  private

  def log_and_empty(message)
    Rails.logger.error(message)
    []
  end

  def vk_id_client_id
    GlobalConfigService.load('VK_ID_CLIENT_ID', ENV.fetch('VK_ID_CLIENT_ID', nil))
  end

  def vk_id_client_secret
    GlobalConfigService.load('VK_ID_CLIENT_SECRET', ENV.fetch('VK_ID_CLIENT_SECRET', nil))
  end

  def base_url
    ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
  end
end
