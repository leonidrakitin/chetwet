require 'ruby_llm'

# Global RubyLLM configuration and per-request context management.
#
# Configures RubyLLM once on first use with system-level API keys from InstallationConfig.
# Provides `with_api_key` for per-request overrides (used by BaseAiService and ChatHelper).
module Llm::Config
  DEFAULT_MODEL = 'deepseek-chat'.freeze

  # Provider configs shared with BaseAiService to avoid duplication.
  # Maps RubyLLM config attribute prefixes to InstallationConfig key names.
  PROVIDER_CONFIGS = {
    'openai' => {
      key_name: 'CAPTAIN_OPEN_AI_API_KEY',
      endpoint_name: 'CAPTAIN_OPEN_AI_ENDPOINT',
      default_endpoint: 'https://api.openai.com/',
      ruby_llm_prefix: 'openai'
    },
    'deepseek' => {
      key_name: 'CAPTAIN_DEEPSEEK_API_KEY',
      endpoint_name: 'CAPTAIN_DEEPSEEK_ENDPOINT',
      default_endpoint: 'https://api.deepseek.com/',
      ruby_llm_prefix: 'deepseek'
    },
    'qwen' => {
      key_name: 'CAPTAIN_QWEN_API_KEY',
      endpoint_name: 'CAPTAIN_QWEN_ENDPOINT',
      default_endpoint: 'https://dashscope.aliyuncs.com/compatible-mode/',
      ruby_llm_prefix: 'qwen'
    },
    'ollama' => {
      key_name: 'CAPTAIN_OLLAMA_API_KEY',
      endpoint_name: 'CAPTAIN_OLLAMA_ENDPOINT',
      default_endpoint: 'http://172.17.0.1:11434/',
      ruby_llm_prefix: 'ollama'
    }
  }.freeze

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

    def with_api_key(api_key, api_base: nil)
      context = RubyLLM.context do |config|
        config.openai_api_key = api_key
        config.openai_api_base = api_base
        config.openai_use_system_role = true
      end

      yield context
    end

    private

    def configure_ruby_llm
      RubyLLM.configure do |config|
        config.openai_use_system_role = true
        config.logger = Rails.logger

        PROVIDER_CONFIGS.each_value { |provider| configure_provider(config, provider) }
      end
    end

    def configure_provider(config, provider)
      api_key = fetch_config(provider[:key_name])
      return if api_key.blank?

      prefix = provider[:ruby_llm_prefix]
      key_setter = :"#{prefix}_api_key="
      return unless config.respond_to?(key_setter)

      config.public_send(key_setter, api_key)

      # Only set api_base when the gem supports it (e.g. openai does, deepseek/qwen may not)
      base_setter = :"#{prefix}_api_base="
      return unless config.respond_to?(base_setter)

      endpoint = fetch_config(provider[:endpoint_name]).presence || provider[:default_endpoint]
      config.public_send(base_setter, endpoint.chomp('/'))
    end

    def fetch_config(name)
      InstallationConfig.find_by(name: name)&.value
    end
  end
end
