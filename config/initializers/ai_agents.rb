# frozen_string_literal: true

require 'agents'

Rails.application.config.after_initialize do
  cfg = Llm::Config.provider_config
  providers_hash = cfg&.dig('providers') || {}

  model = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value.presence || LlmConstants::DEFAULT_MODEL

  Agents.configure do |config|
    configure_openai(config, providers_hash['openai'])
    configure_openrouter(config, providers_hash['openrouter'])
    configure_anthropic(config, providers_hash['anthropic'])
    configure_gemini(config, providers_hash['gemini'])
    configure_deepseek(config, providers_hash['deepseek'])
    configure_ollama(config, providers_hash['ollama'])

    configure_openai_compatible(config, 'qwen', providers_hash)
    configure_openai_compatible(config, 'zai', providers_hash)

    config.default_model = model
    config.debug = false
  end
rescue StandardError => e
  Rails.logger.error "Failed to configure AI Agents SDK: #{e.message}"
end

def configure_openai(config, provider_cfg)
  return if provider_cfg.blank? || provider_cfg['enabled'] != true
  return if provider_cfg['api_key'].blank?

  config.openai_api_key = provider_cfg['api_key']
  config.openai_api_base = normalize_api_base(provider_cfg['api_base']) if provider_cfg['api_base'].present?
end

def configure_openrouter(config, provider_cfg)
  return if provider_cfg.blank? || provider_cfg['enabled'] != true
  return if provider_cfg['api_key'].blank?

  config.openrouter_api_key = provider_cfg['api_key']
  config.openrouter_api_base = normalize_openrouter_base(provider_cfg['api_base']) if provider_cfg['api_base'].present?
end

def configure_anthropic(config, provider_cfg)
  return if provider_cfg.blank? || provider_cfg['enabled'] != true
  return if provider_cfg['api_key'].blank?

  config.anthropic_api_key = provider_cfg['api_key']
end

def configure_gemini(config, provider_cfg)
  return if provider_cfg.blank? || provider_cfg['enabled'] != true
  return if provider_cfg['api_key'].blank?

  config.gemini_api_key = provider_cfg['api_key']
end

def configure_deepseek(config, provider_cfg)
  return if provider_cfg.blank? || provider_cfg['enabled'] != true
  return if provider_cfg['api_key'].blank?

  config.deepseek_api_key = provider_cfg['api_key']
  config.deepseek_api_base = provider_cfg['api_base'] if provider_cfg['api_base'].present?
end

def configure_ollama(config, provider_cfg)
  return if provider_cfg.blank? || provider_cfg['enabled'] != true
  return if provider_cfg['api_base'].blank?

  config.ollama_api_base = provider_cfg['api_base']
end

def configure_openai_compatible(config, provider_name, providers_hash)
  provider_cfg = providers_hash[provider_name]
  return if provider_cfg.blank? || provider_cfg['enabled'] != true
  return if provider_cfg['api_key'].blank?

  config.openai_api_key = provider_cfg['api_key']
  config.openai_api_base = normalize_api_base(provider_cfg['api_base']) if provider_cfg['api_base'].present?
end

def normalize_api_base(raw)
  return nil if raw.blank?

  base = raw.is_a?(Hash) ? (raw[:value] || raw['value']).to_s : raw.to_s
  base = base.strip.chomp('/')
  return nil if base.blank?

  %r{/v\d+/?$}.match?(base) ? base : "#{base}/v1"
end

def normalize_openrouter_base(raw)
  return nil if raw.blank?

  base = raw.is_a?(Hash) ? (raw[:value] || raw['value']).to_s : raw.to_s
  base = base.strip.chomp('/')
  return nil if base.blank?

  base.match?(%r{/api/v1/?$}) ? base : "#{base}/api/v1"
end
