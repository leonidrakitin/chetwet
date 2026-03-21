# frozen_string_literal: true

# VK channel inbox: settings UI → PKCE authorize → GET /vk/callback (not agent login; that is OmniAuth vkid + VkIdOAuthButton).
class Api::V1::Accounts::Vk::AuthorizationsController < Api::V1::Accounts::OauthAuthorizationController
  include VkConcern
  include Vk::IntegrationHelper

  # Exchange authorization code for tokens (PKCE verifier comes from frontend)
  def create
    token_response = exchange_code_for_tokens
    unless token_response
      render json: { error: 'Failed to exchange authorization code' }, status: :unprocessable_entity
      return
    end

    # Store tokens in Redis (15 min TTL) keyed by a random handle
    token_handle = SecureRandom.hex(16)
    Redis::Alfred.setex("vk_oauth:#{token_handle}", token_response.to_json, 15.minutes)

    render json: { success: true, token_handle: token_handle }
  end

  private

  def exchange_code_for_tokens
    body = {
      client_id: vk_id_client_id,
      redirect_uri: "#{base_url}/vk/callback",
      code: params[:code],
      code_verifier: params[:code_verifier],
      device_id: params[:device_id],
      grant_type: 'authorization_code',
      state: params[:state]
    }

    response = HTTParty.post('https://id.vk.com/oauth2/auth', body: body)

    unless response.success?
      Rails.logger.error "[VK] Token exchange failed: #{response.code} #{response.body}"
      return nil
    end

    parsed = response.parsed_response
    return nil if parsed['access_token'].blank?

    {
      access_token: parsed['access_token'],
      refresh_token: parsed['refresh_token'],
      expires_in: parsed['expires_in'],
      user_id: parsed['user_id']
    }
  end
end
