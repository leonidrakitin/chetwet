# frozen_string_literal: true

# VK channel inbox OAuth redirect target after id.vk.com (tokens → Redis → dashboard completes inbox).
class Vk::CallbacksController < ApplicationController
  def show
    return redirect_with_error(params[:error_description] || 'Authorization was denied') if params[:error].present?

    # Read return_path from state (account_id:random_hex)
    account_id, = parse_state(params[:state])

    redirect_to app_new_vk_inbox_url(
      account_id: account_id || 0,
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
    [parts[0], parts[1]]
  end

  def redirect_with_error(message)
    account_id, = parse_state(params[:state])
    redirect_to app_new_vk_inbox_url(
      account_id: account_id || 0,
      error_message: message
    )
  end
end
