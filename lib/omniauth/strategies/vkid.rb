# frozen_string_literal: true

require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class Vkid < OmniAuth::Strategies::OAuth2
      option :name, 'vkid'

      option :client_options, {
        site: 'https://id.vk.com',
        authorize_url: 'https://id.vk.com/authorize',
        token_url: 'https://id.vk.com/oauth2/auth'
      }

      option :authorize_params, {
        scope: 'email groups messages offline' #phone
      }

      uid { raw_info['user_id'].to_s }

      info do
        {
          'email' => raw_info['email'],
          'name' => [raw_info['first_name'], raw_info['last_name']].compact.join(' '),
          'first_name' => raw_info['first_name'],
          'last_name' => raw_info['last_name'],
          'image' => raw_info['avatar'],
          'email_verified' => raw_info['email'].present?
        }
      end

      extra do
        { 'raw_info' => raw_info }
      end

      # VK ID requires device_id in both authorize and token requests.
      # PKCE (code_challenge / code_verifier) and state are added by omniauth-oauth2 when pkce: true
      # and default authorize_params (see config/initializers/omniauth.rb).
      def authorize_params
        super.tap do |params|
          params[:device_id] = session['vkid.device_id'] ||= SecureRandom.uuid
        end
      end

      # Override token exchange to include device_id required by VK ID API.
      # token_params includes code_verifier from session (PKCE) when pkce is enabled.
      def build_access_token
        verifier = request.params['code']
        device_id = request.params['device_id'] || session.delete('vkid.device_id') || SecureRandom.uuid

        client.auth_code.get_token(
          verifier,
          { redirect_uri: callback_url, device_id: device_id }
            .merge(token_params.to_hash(symbolize_keys: true)),
          deep_symbolize(options.auth_token_params)
        )
      end

      private

      def raw_info
        @raw_info ||= fetch_user_info
      end

      def fetch_user_info
        response = client.request(:post, 'https://id.vk.com/oauth2/user_info', {
                                    body: {
                                      client_id: options.client_id,
                                      access_token: access_token.token
                                    }
                                  })
        JSON.parse(response.body)['user'] || {}
      rescue StandardError => e
        Rails.logger.error("VK ID user info fetch failed: #{e.message}")
        {}
      end
    end
  end
end
