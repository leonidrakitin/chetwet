# frozen_string_literal: true

# VK channel inbox OAuth redirect target after id.vk.com (tokens → Redis → dashboard completes inbox).
# NOTE: VK ID OAuth does not reliably return the `state` parameter, so account_id and nonce
# are stored in the vk_oauth_state_nonce cookie (format: "accountId:randomHex") instead.
class Vk::CallbacksController < ApplicationController
  def show
    return redirect_with_error(params[:error_description] || 'Authorization was denied') if params[:error].present?

    account_id, cookie_nonce = parse_cookie_value(cookies[:vk_oauth_state_nonce])
    return redirect_with_error('Invalid state parameter') if account_id.nil?
    return redirect_with_error('Invalid authorization state') unless valid_state_nonce?(cookie_nonce)

    complete_oauth(account_id)
  rescue StandardError => e
    Rails.logger.error("VK Callback Error: #{e.message}")
    redirect_with_error(e.message)
  end

  private

  def complete_oauth(account_id)
    clear_state_nonce_cookie
    redirect_to app_new_vk_inbox_url(account_id: account_id, code: params[:code],
                                     device_id: params[:device_id], state: params[:state])
  end

  # When VK returns state, verify its nonce matches the cookie nonce.
  # If state is absent (VK ID sometimes omits it), skip the check.
  def valid_state_nonce?(cookie_nonce)
    return true if params[:state].blank?

    _, state_nonce = parse_state(params[:state])
    state_nonce.present? && ActiveSupport::SecurityUtils.secure_compare(state_nonce, cookie_nonce)
  end

  # Cookie format: "accountId:randomHex" (32 hex chars)
  def parse_cookie_value(cookie)
    parse_nonce_string(cookie)
  end

  # State format: "accountId:randomHex" — same structure, used for optional cross-check
  def parse_state(state)
    parse_nonce_string(state)
  end

  def parse_nonce_string(value)
    return [nil, nil] if value.blank?

    parts = value.split(':', 2)
    return [nil, nil] if parts[1].blank?
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
    redirect_to app_new_vk_inbox_url(account_id: account_id || 0, error_message: message)
  end
end
