# frozen_string_literal: true

require 'agents'

Rails.application.config.after_initialize do
  cfg = Llm::Config.provider_config

  primary = cfg&.dig('primary_provider') || 'openai'
  providers_hash = cfg&.dig('providers') || {}
  provider_cfg = providers_hash[primary] || {}

  api_key = provider_cfg['api_key']
  api_base = provider_cfg['api_base']

  model = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value.presence || LlmConstants::DEFAULT_MODEL

  if api_key.present?
    Agents.configure do |config|
      config.openai_api_key = api_key
      if api_base.present?
        base = api_base.chomp('/')
        api_base_normalized = %r{/v\d+/?$}.match?(base) ? base : "#{base}/v1"
        config.openai_api_base = api_base_normalized
      end
      config.default_model = model
      config.debug = false
    end
  end
rescue StandardError => e
  Rails.logger.error "Failed to configure AI Agents SDK: #{e.message}"
end
