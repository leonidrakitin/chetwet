# frozen_string_literal: true

class Api::V1::Accounts::Vk::AuthorizationsController < Api::V1::Accounts::OauthAuthorizationController
  include VkConcern
  include Vk::IntegrationHelper

  def create
    pkce_pair = generate_pkce_pair
    state_token = generate_vk_token(Current.account.id)

    # Store PKCE verifier for use in callback (10 min TTL)
    Redis::Alfred.setex("vk_pkce:#{state_token}", pkce_pair[:code_verifier].to_json, 10.minutes)

    redirect_url = vk_oauth_client.auth_code.authorize_url(
      redirect_uri: "#{base_url}/vk/callback",
      scope: 'groups,messages,offline',
      response_type: 'code',
      state: state_token,
      code_challenge: pkce_pair[:code_challenge],
      code_challenge_method: 'S256'
    )

    if redirect_url
      render json: { success: true, url: redirect_url }
    else
      render json: { success: false }, status: :unprocessable_entity
    end
  end
end
