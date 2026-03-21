# frozen_string_literal: true

class Vk::CallbacksController < ApplicationController
  include VkConcern
  include Vk::IntegrationHelper

  def show
    if params[:error].present?
      handle_authorization_error
      return
    end

    process_successful_authorization
  rescue StandardError => e
    handle_error(e)
  end

  def process_successful_authorization
    token_response = exchange_code_for_tokens(params[:code])
    unless token_response
      redirect_to_error_page('token_exchange_failed', 'Failed to exchange authorization code')
      return
    end

    # Store tokens in Redis (15 min TTL) keyed by a random handle
    token_handle = SecureRandom.hex(16)
    Redis::Alfred.setex("vk_oauth:#{token_handle}", token_response.to_json, 15.minutes)

    redirect_to app_new_vk_inbox_url(
      account_id: account_id,
      token_handle: token_handle
    )
  end

  def exchange_code_for_tokens(code)
    # Get PKCE verifier from Redis
    pkce_verifier = fetch_pkce_verifier(params[:state])

    body = {
      client_id: vk_id_client_id,
      client_secret: vk_id_client_secret,
      redirect_uri: "#{base_url}/vk/callback",
      code: code,
      grant_type: 'authorization_code'
    }
    body[:code_verifier] = pkce_verifier if pkce_verifier.present?

    response = HTTParty.post(
      'https://id.vk.com/oauth2/token',
      body: body
    )
    return nil unless response.success?

    parsed = response.parsed_response
    return nil if parsed['access_token'].blank?

    {
      access_token: parsed['access_token'],
      refresh_token: parsed['refresh_token'],
      expires_in: parsed['expires_in'],
      user_id: parsed['user_id']
    }
  end

  def fetch_pkce_verifier(state)
    raw = Redis::Alfred.get("vk_pkce:#{state}")
    return nil if raw.blank?

    JSON.parse(raw)
  end

  def handle_authorization_error
    redirect_to_error_page(
      params[:error] || 'authorization_error',
      params[:error_description] || 'Authorization was denied'
    )
  end

  def handle_error(error)
    Rails.logger.error("VK Channel creation Error: #{error.message}")
    ChatwootExceptionTracker.new(error).capture_exception
    redirect_to_error_page(error.class.name, error.message)
  end

  def redirect_to_error_page(error_type, error_message)
    redirect_to app_new_vk_inbox_url(
      account_id: account_id,
      error_type: error_type,
      error_message: error_message
    )
  end

  def account_id
    return unless params[:state]

    verify_vk_token(params[:state])
  end

  private

  def vk_id_client_id
    GlobalConfigService.load('VK_ID_CLIENT_ID', ENV.fetch('VK_ID_CLIENT_ID', nil))
  end

  def vk_id_client_secret
    GlobalConfigService.load('VK_ID_CLIENT_SECRET', ENV.fetch('VK_ID_CLIENT_SECRET', nil))
  end
end
