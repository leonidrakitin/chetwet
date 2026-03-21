# frozen_string_literal: true

module Vk::IntegrationHelper
  def generate_vk_token(account_id)
    return if vk_client_secret.blank?

    JWT.encode(vk_token_payload(account_id), vk_client_secret, 'HS256')
  rescue StandardError => e
    Rails.logger.error("Failed to generate VK token: #{e.message}")
    nil
  end

  def verify_vk_token(token)
    return if token.blank? || vk_client_secret.blank?

    JWT.decode(token, vk_client_secret, true, {
                 algorithm: 'HS256'
               }).first['sub']
  rescue StandardError => e
    Rails.logger.error("Unexpected error verifying VK token: #{e.message}")
    nil
  end

  private

  def vk_token_payload(account_id)
    {
      sub: account_id,
      iat: Time.current.to_i
    }
  end
end
