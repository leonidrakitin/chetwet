# frozen_string_literal: true

# VK channel inbox: settings UI → PKCE authorize → GET /vk/callback (not agent login; that is OmniAuth vkid + VkIdOAuthButton).
class Api::V1::Accounts::Vk::AuthorizationsController < Api::V1::Accounts::OauthAuthorizationController
  include VkConcern
  include Vk::IntegrationHelper

  def create
    pkce_pair = generate_pkce_pair
    state_token = generate_vk_token(Current.account.id)

    # Store PKCE verifier for use in callback (10 min TTL)
    Redis::Alfred.setex("vk_pkce:#{state_token}", pkce_pair[:code_verifier], 10.minutes)

    params = {
      client_id: vk_id_client_id,
      redirect_uri: "#{base_url}/vk/callback",
      response_type: 'code',
      scope: 'groups messages',
      state: state_token,
      code_challenge: pkce_pair[:code_challenge],
      code_challenge_method: 'S256'
    }

    redirect_url = "https://id.vk.com/authorize?#{params.to_query}"

    render json: { success: true, url: redirect_url }
  end
end
