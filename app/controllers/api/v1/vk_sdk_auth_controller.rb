# frozen_string_literal: true

class Api::V1::VkSdkAuthController < ApplicationController
  def create
    user_info = fetch_vk_user_info
    email = user_info&.dig('email')

    return render json: { error: 'email_not_provided' }, status: :unprocessable_entity if email.blank?

    user = User.from_email(email)
    return render json: { error: 'no-account-found' }, status: :not_found unless user

    user.skip_confirmation! if user.respond_to?(:skip_confirmation!) && !user.confirmed?
    render json: { email: user.email, sso_auth_token: user.generate_sso_auth_token }
  end

  private

  def fetch_vk_user_info
    uri = URI('https://id.vk.com/oauth2/user_info')
    response = Net::HTTP.post_form(uri, {
                                     client_id: ENV.fetch('VK_ID_CLIENT_ID'),
                                     access_token: params[:access_token]
                                   })
    JSON.parse(response.body)['user']
  rescue StandardError => e
    Rails.logger.error("VK SDK user info fetch failed: #{e.message}")
    nil
  end
end
