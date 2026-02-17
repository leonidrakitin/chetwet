# frozen_string_literal: true

# Base service for LLM operations using RubyLLM.
# New features should inherit from this class.
#
# Supports multiple providers (OpenAI, DeepSeek, Qwen, etc.) with automatic
# API key and endpoint resolution based on the selected model's provider.
# Provider configs are resolved from InstallationConfig using a naming convention:
#   CAPTAIN_{PROVIDER}_API_KEY, CAPTAIN_{PROVIDER}_ENDPOINT
class Llm::BaseAiService
  DEFAULT_MODEL = Llm::Config::DEFAULT_MODEL
  DEFAULT_TEMPERATURE = 1.0

  # Provider registry defined in Llm::Config::PROVIDER_CONFIGS.
  # To add a new provider, add an entry there and configure keys in InstallationConfig.
  PROVIDER_CONFIGS = Llm::Config::PROVIDER_CONFIGS

  # Default provider used when a model's provider has no dedicated config
  DEFAULT_PROVIDER = 'openai'

  attr_reader :model, :temperature

  def initialize(account: nil)
    Llm::Config.initialize!
    @account = account
    setup_model
    setup_temperature
  end

  def chat(model: @model, temperature: @temperature)
    Llm::Config.with_api_key(resolve_api_key(model), api_base: resolve_api_base(model)) do |context|
      context.chat(model: model, provider: :openai, assume_model_exists: true).with_temperature(temperature)
    end
  end

  private

  def setup_model
    config_value = fetch_config('CAPTAIN_OPEN_AI_MODEL')
    @model = config_value.presence || DEFAULT_MODEL
  end

  def setup_temperature
    @temperature = DEFAULT_TEMPERATURE
  end

  # Resolves provider name for a given model from llm.yml config.
  # Falls back to DEFAULT_PROVIDER if the model is not found.
  def provider_for(model_name)
    Llm::Models.models.dig(model_name, 'provider') || DEFAULT_PROVIDER
  end

  # Returns the provider config hash, falling back to openai for unknown providers.
  def provider_config_for(model_name)
    provider = provider_for(model_name)
    PROVIDER_CONFIGS[provider] || PROVIDER_CONFIGS[DEFAULT_PROVIDER]
  end

  # Resolves the API key for a model. Tries the model's provider first,
  # then falls back to the default (OpenAI) provider key.
  def resolve_api_key(model_name)
    config = provider_config_for(model_name)
    key = fetch_config(config[:key_name])
    return key if key.present?

    # Fall back to default provider key if the model's provider has no key configured
    return fetch_config(PROVIDER_CONFIGS[DEFAULT_PROVIDER][:key_name]) if config != PROVIDER_CONFIGS[DEFAULT_PROVIDER]

    key
  end

  # Resolves the API base URL for a model. Uses the model's provider endpoint
  # if its API key is present, otherwise falls back to the default provider.
  def resolve_api_base(model_name)
    config = provider_config_for(model_name)
    key = fetch_config(config[:key_name])

    active_config = if key.present?
                      config
                    else
                      PROVIDER_CONFIGS[DEFAULT_PROVIDER]
                    end

    build_api_base(active_config)
  end

  def build_api_base(config)
    endpoint = fetch_config(config[:endpoint_name]).presence || config[:default_endpoint]
    endpoint = endpoint.chomp('/')
    "#{endpoint}/v1"
  end

  # Fetches a config value from InstallationConfig with memoization.
  # Uses instance-level cache to avoid repeated DB lookups within a single service call.
  def fetch_config(name)
    @config_cache ||= {}
    return @config_cache[name] if @config_cache.key?(name)

    @config_cache[name] = InstallationConfig.find_by(name: name)&.value
  end
end
