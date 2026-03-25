# frozen_string_literal: true

# VK channel inbox OAuth redirect target after id.vk.com (tokens → Redis → dashboard completes inbox).
# NOTE: VK ID modifies the state parameter, so CSRF protection relies solely on the
# vk_oauth_state_nonce cookie (format: "accountId:randomHex"), which is same-domain only.
class Vk::CallbacksController < ApplicationController
  def show
    return redirect_with_error(params[:error_description] || 'Authorization was denied') if params[:error].present?

    account_id, = parse_cookie(cookies[:vk_oauth_state_nonce])
    return redirect_with_error('Invalid state parameter') if account_id.nil?

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

  # Cookie format: "accountId:randomHex" (32 hex chars)
  def parse_cookie(cookie)
    return [nil, nil] if cookie.blank?

    parts = cookie.split(':', 2)
    return [nil, nil] if parts[1].blank?
    return [nil, nil] unless parts[0].match?(/\A\d+\z/)
    return [nil, nil] unless parts[1].match?(/\A\h{32}\z/)

    [parts[0].to_i, parts[1]]
  end

  def clear_state_nonce_cookie
    cookies.delete(:vk_oauth_state_nonce, path: '/')
  end

  def redirect_with_error(message)
    account_id, = parse_cookie(cookies[:vk_oauth_state_nonce])
    clear_state_nonce_cookie
    redirect_to app_new_vk_inbox_url(account_id: account_id || 0, error_message: message)
  end
end
