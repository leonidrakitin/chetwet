# frozen_string_literal: true

# Mobile/native VK SDK: POST /api/v1/auth/vk_sdk_callback with access_token (not browser OmniAuth).
class Api::V1::VkSdkAuthController < ApplicationController
  include EmailHelper
  include OauthSignupTokenable

  def create
    user_info = fetch_vk_user_info
    email = user_info&.dig('email')

    return render json: { error: 'email_not_provided' }, status: :unprocessable_entity if email.blank?

    existing_user = User.from_email(email)
    if existing_user
      process_auth_response(existing_user, existing_user)
    else
      full_name = [user_info['first_name'], user_info['last_name']].compact.join(' ').presence
      token = generate_oauth_signup_token(
        email: email,
        name: full_name,
        provider: 'vk',
        avatar_url: user_info['avatar'],
        email_verified: true
      )
      render json: { needs_signup: true, signup_token: token, email: email }
    end
  end

  private

  def process_auth_response(user, existing_user)
    user.skip_confirmation! if user.respond_to?(:skip_confirmation!) && !user.confirmed?
    render json: build_auth_response(user, existing_user)
  end

  def build_auth_response(user, existing_user)
    response_data = { email: user.email, sso_auth_token: user.generate_sso_auth_token }
    response_data[:redirect] = '/app/onboarding/wizard' unless existing_user
    response_data
  end

  def fetch_vk_user_info
    # Same host as lib/omniauth/strategies/vkid.rb (id.vk.com, not id.vk.ru).
    uri = URI('https://id.vk.com/oauth2/user_info')
    response = Net::HTTP.post_form(uri, {
                                     client_id: vk_id_client_id,
                                     access_token: params[:access_token]
                                   })
    JSON.parse(response.body)['user']
  rescue StandardError => e
    Rails.logger.error("VK SDK user info fetch failed: #{e.message}")
    nil
  end

  def vk_id_client_id
    GlobalConfigService.load('VK_ID_CLIENT_ID', ENV.fetch('VK_ID_CLIENT_ID', nil))
  end
end
