# frozen_string_literal: true

require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class YandexId < OmniAuth::Strategies::OAuth2
      option :name, 'yandex_id'

      option :client_options, {
        site: 'https://oauth.yandex.ru',
        authorize_url: 'https://oauth.yandex.ru/authorize',
        token_url: 'https://oauth.yandex.ru/token'
      }

      uid { raw_info['id'].to_s }

      info do
        {
          'email' => raw_info['default_email'],
          'name' => raw_info['real_name'].presence || raw_info['display_name'],
          'first_name' => raw_info['first_name'],
          'last_name' => raw_info['last_name'],
          'image' => avatar_url,
          'email_verified' => raw_info['default_email'].present?
        }
      end

      extra do
        { 'raw_info' => raw_info }
      end

      private

      def raw_info
        @raw_info ||= fetch_user_info
      end

      def fetch_user_info
        response = access_token.get('https://login.yandex.ru/info?format=json')
        JSON.parse(response.body)
      rescue StandardError => e
        Rails.logger.error("Yandex ID user info fetch failed: #{e.message}")
        {}
      end

      def avatar_url
        avatar_id = raw_info['default_avatar_id']
        return nil if avatar_id.blank?

        "https://avatars.yandex.net/get-yapic/#{avatar_id}/islands-200"
      end
    end
  end
end
