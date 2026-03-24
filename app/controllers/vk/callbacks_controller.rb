# frozen_string_literal: true

# VK channel inbox OAuth redirect target after id.vk.com (tokens → Redis → dashboard completes inbox).
class Vk::CallbacksController < ApplicationController
  def show
    return redirect_with_error(params[:error_description] || 'Authorization was denied') if params[:error].present?

    # Read return_path from state (account_id:random_hex)
    account_id, state_nonce = parse_state(params[:state])
    return redirect_with_error('Invalid state parameter') if account_id.nil?
    return redirect_with_error('Invalid authorization state') unless valid_state_nonce?(state_nonce)

    clear_state_nonce_cookie

    redirect_to app_new_vk_inbox_url(
      account_id: account_id,
      code: params[:code],
      device_id: params[:device_id],
      state: params[:state]
    )
  rescue StandardError => e
    Rails.logger.error("VK Callback Error: #{e.message}")
    redirect_with_error(e.message)
  end

  private

  def parse_state(state)
    # State format: "accountId:randomHex"
    return [nil, nil] if state.blank?

    parts = state.split(':', 2)
    return [nil, nil] unless parts[1].present?
    return [nil, nil] unless parts[0].match?(/\A\d+\z/)
    return [nil, nil] unless parts[1].match?(/\A\h{32}\z/)

    [parts[0].to_i, parts[1]]
  end

  def valid_state_nonce?(state_nonce)
    cookie_nonce = cookies[:vk_oauth_state_nonce]
    return false if state_nonce.blank? || cookie_nonce.blank?

    ActiveSupport::SecurityUtils.secure_compare(state_nonce, cookie_nonce)
  rescue StandardError
    false
  end

  def clear_state_nonce_cookie
    cookies.delete(:vk_oauth_state_nonce, path: '/')
  end

  def redirect_with_error(message)
    account_id, = parse_state(params[:state])
    clear_state_nonce_cookie
    redirect_to app_new_vk_inbox_url(
      account_id: account_id || 0,
      error_message: message
    )
  end
end
