# OmniAuth configuration
# Sets the full host URL for callbacks and proper redirect handling
OmniAuth.config.full_host = ENV.fetch('FRONTEND_URL', 'http://localhost:3000')

require_relative '../../lib/omniauth/strategies/vkid'
require_relative '../../lib/omniauth/strategies/yandex_id'

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, ENV.fetch('GOOGLE_OAUTH_CLIENT_ID', nil), ENV.fetch('GOOGLE_OAUTH_CLIENT_SECRET', nil), {
    provider_ignores_state: true
  }

  provider :vkid, ENV.fetch('VK_ID_CLIENT_ID', nil), ENV.fetch('VK_ID_CLIENT_SECRET', nil), {
    provider_ignores_state: true
  }

  provider :yandex_id, ENV.fetch('YANDEX_OAUTH_CLIENT_ID', nil), ENV.fetch('YANDEX_OAUTH_CLIENT_SECRET', nil), {
    provider_ignores_state: true
  }
end
