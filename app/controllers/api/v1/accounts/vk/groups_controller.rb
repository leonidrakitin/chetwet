# frozen_string_literal: true

class Api::V1::Accounts::Vk::GroupsController < Api::V1::Accounts::BaseController
  include VkConcern

  before_action :check_authorization

  def index
    token_data = fetch_token_data
    unless token_data
      render json: { error: 'Token not found or expired' }, status: :unprocessable_entity
      return
    end

    groups = fetch_vk_groups(token_data['access_token'], user_id: token_data['user_id'])
    render json: { groups: groups, token_data: token_data }
  end

  private

  def fetch_token_data
    raw = Redis::Alfred.get("vk_oauth:#{params[:token_handle]}")
    return nil if raw.blank?

    JSON.parse(raw)
  end

  def check_authorization
    raise Pundit::NotAuthorizedError unless Current.account_user.administrator?
  end
end
