# frozen_string_literal: true

# VK channel inbox OAuth redirect target after id.vk.com (tokens → Redis → dashboard completes inbox).
# NOTE: VK ID OAuth does not reliably return the `state` parameter, so account_id and nonce
# are stored in the vk_oauth_state_nonce cookie (format: "accountId:randomHex") instead.
class Vk::CallbacksController < ApplicationController
  def show
    return redirect_with_error(params[:error_description] || 'Authorization was denied') if params[:error].present?

    # Read account_id and nonce from cookie — VK ID may not return `state` in the callback
    account_id, cookie_nonce = parse_cookie_value(cookies[:vk_oauth_state_nonce])
    return redirect_with_error('Invalid state parameter') if account_id.nil?

    # When VK does return state, verify the nonce matches
    if params[:state].present?
      _, state_nonce = parse_state(params[:state])
      unless state_nonce.present? && ActiveSupport::SecurityUtils.secure_compare(state_nonce, cookie_nonce)
        clear_state_nonce_cookie
        return redirect_with_error('Invalid authorization state')
      end
    end

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

  # Cookie format: "accountId:randomHex" (32 hex chars)
  def parse_cookie_value(cookie)
    return [nil, nil] if cookie.blank?

    parts = cookie.split(':', 2)
    return [nil, nil] unless parts[1].present?
    return [nil, nil] unless parts[0].match?(/\A\d+\z/)
    return [nil, nil] unless parts[1].match?(/\A\h{32}\z/)

    [parts[0].to_i, parts[1]]
  end

  # State format: "accountId:randomHex" — same structure, used for optional cross-check
  def parse_state(state)
    return [nil, nil] if state.blank?

    parts = state.split(':', 2)
    return [nil, nil] unless parts[1].present?
    return [nil, nil] unless parts[0].match?(/\A\d+\z/)
    return [nil, nil] unless parts[1].match?(/\A\h{32}\z/)

    [parts[0].to_i, parts[1]]
  end

  def clear_state_nonce_cookie
    cookies.delete(:vk_oauth_state_nonce, path: '/')
  end

  def redirect_with_error(message)
    account_id, = parse_cookie_value(cookies[:vk_oauth_state_nonce])
    clear_state_nonce_cookie
    redirect_to app_new_vk_inbox_url(
      account_id: account_id || 0,
      error_message: message
    )
  end
end
