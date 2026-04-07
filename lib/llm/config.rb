require 'ruby_llm'

module Llm::Config
  DEFAULT_MODEL = 'gpt-4.1-mini'.freeze

  class << self
    def initialized?
      @initialized ||= false
    end

    def initialize!
      return if @initialized

      configure_ruby_llm
      @initialized = true
    end

    def reset!
      @initialized = false
    end

    def with_api_key(api_key, api_base: nil, provider: nil)
      context = RubyLLM.context do |config|
        if provider == :openrouter
          config.openrouter_api_key = api_key
        else
          config.openai_api_key = api_key
          config.openai_api_base = api_base
        end
        config.openai_use_system_role = true
      end

      yield context
    end

    # Provider symbol based on CAPTAIN_HOST setting.
    def current_provider
      captain_host == 'openrouter' ? :openrouter : :openai
    end

    # API key and base URL for RubyLLM.embed (Captain embeddings). Optional dedicated endpoint/key
    # allow routing embeddings to direct OpenAI while chat uses OpenRouter.
    def embedding_openai_credentials
      key = InstallationConfig.find_by(name: 'CAPTAIN_EMBEDDING_OPEN_AI_API_KEY')&.value.presence || system_api_key
      dedicated = InstallationConfig.find_by(name: 'CAPTAIN_EMBEDDING_OPEN_AI_ENDPOINT')&.value
      base = normalize_openai_api_base(dedicated.presence || openai_endpoint)
      [key, base]
    end

    # Normalized OpenAI-compatible base URL for Captain tasks (summarize, reply suggestion, etc.).
    # Matches RubyLLM global config and avoids double /v1 when the endpoint already includes it (e.g. OpenRouter).
    def captain_openai_api_base
      raw = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value
      normalize_openai_api_base(raw.presence || 'https://api.openai.com')
    end

    private

    def configure_ruby_llm
      RubyLLM.configure do |config|
        case captain_host
        when 'openrouter'
          config.openrouter_api_key = system_api_key if system_api_key.present?
        else
          config.openai_api_key = system_api_key if system_api_key.present?
          normalized = normalize_openai_api_base(openai_endpoint)
          config.openai_api_base = normalized if normalized.present?
        end
        config.openai_use_system_role = true
        config.logger = Rails.logger
        registry = Rails.root.join('storage/ruby_llm_models.json').to_s
        config.model_registry_file = registry if File.exist?(registry)
      end
    end

    def normalize_openai_api_base(raw)
      return nil if raw.blank?

      base = raw.is_a?(Hash) ? (raw[:value] || raw['value']).to_s : raw.to_s
      base = base.strip.chomp('/')
      return nil if base.blank?

      # OpenRouter serves the OpenAI-compatible API under /api/v1, not /v1 on the domain root.
      return "#{base}/api/v1" if base.match?(%r{\Ahttps?://openrouter\.ai\z}i)

      %r{/v\d+/?$}.match?(base) ? base : "#{base}/v1"
    end

    def captain_host
      InstallationConfig.find_by(name: 'CAPTAIN_HOST')&.value
    end

    def system_api_key
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
    end

    def openai_endpoint
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value
    end
  end
end
