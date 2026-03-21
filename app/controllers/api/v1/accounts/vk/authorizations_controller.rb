# frozen_string_literal: true

class Api::V1::Accounts::Vk::AuthorizationsController < Api::V1::Accounts::OauthAuthorizationController
  include VkConcern
  include Vk::IntegrationHelper

  def create
    redirect_url = vk_oauth_client.auth_code.authorize_url(
      redirect_uri: "#{base_url}/vk/callback",
      scope: 'groups,messages,offline',
      response_type: 'code',
      state: generate_vk_token(Current.account.id)
    )

    if redirect_url
      render json: { success: true, url: redirect_url }
    else
      render json: { success: false }, status: :unprocessable_entity
    end
  end
end
