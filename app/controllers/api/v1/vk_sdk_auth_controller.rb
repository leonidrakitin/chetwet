# frozen_string_literal: true

class Api::V1::VkSdkAuthController < ApplicationController
  include EmailHelper

  def create
    user_info = fetch_vk_user_info
    email = user_info&.dig('email')

    return render json: { error: 'email_not_provided' }, status: :unprocessable_entity if email.blank?

    user = User.from_email(email) || create_account_for_user(user_info, email)
    return render json: { error: 'account_creation_failed' }, status: :unprocessable_entity unless user&.persisted?

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

  def create_account_for_user(user_info, email)
    full_name = [user_info['first_name'], user_info['last_name']].compact.join(' ').presence

    user, _account = AccountBuilder.new(
      account_name: extract_domain_without_tld(email),
      user_full_name: full_name,
      email: email,
      locale: I18n.locale,
      confirmed: true
    ).perform
    user
  rescue StandardError => e
    Rails.logger.error("VK SDK account creation failed: #{e.message}")
    nil
  end
end
