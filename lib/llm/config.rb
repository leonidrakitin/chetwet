require 'ruby_llm'

module Llm::Config
  DEFAULT_MODEL = 'gpt-4.1-mini'.freeze

  PROVIDER_MAP = {
    'openai' => :openai,
    'openrouter' => :openrouter,
    'anthropic' => :anthropic,
    'gemini' => :gemini,
    'deepseek' => :openai,
    'qwen' => :openai,
    'zai' => :openai,
    'ollama' => :ollama
  }.freeze

  DEFAULT_ENDPOINTS = {
    'openai' => 'https://api.openai.com',
    'openrouter' => 'https://openrouter.ai',
    'anthropic' => 'https://api.anthropic.com',
    'gemini' => 'https://generativelanguage.googleapis.com',
    'deepseek' => 'https://api.deepseek.com',
    'qwen' => 'https://dashscope.aliyuncs.com/compatible-mode',
    'zai' => 'https://open.bigmodel.cn',
    'ollama' => 'http://localhost:11434'
  }.freeze

  class AllProvidersFailedError < StandardError; end

  class << self
    def provider_config
      @provider_config ||= begin
        config = GlobalConfig.get_value('CAPTAIN_PROVIDERS')
        config.presence || migrate_legacy_config
      end
    end

    def primary_provider
      cfg = provider_config
      return :openai if cfg.blank?

      primary = cfg['primary_provider']
      return :openai if primary.blank?

      provider_sym(primary)
    end

    def provider_chain
      cfg = provider_config
      return [:openai] if cfg.blank?

      primary = cfg['primary_provider'].presence || 'openai'
      fallback_order = cfg['fallback_order'] || []
      providers = cfg['providers'] || {}

      chain = [primary]
      chain.concat(fallback_order)

      chain.compact!
      chain.uniq!

      enabled_chain = chain.select do |p|
        provider_cfg = providers[p.to_s]
        provider_cfg.is_a?(Hash) && provider_cfg['enabled'] == true && provider_cfg['api_key'].present?
      end

      enabled_chain.empty? ? [:openai] : enabled_chain.map { |p| provider_sym(p) }
    end

    def with_provider(provider_key = nil, api_key_override: nil)
      provider = provider_key || primary_provider
      cfg = provider_config
      providers_hash = cfg['providers'] || {} if cfg.present?

      provider_cfg = providers_hash&.dig(provider.to_s) || {}

      api_key = api_key_override || provider_cfg['api_key']
      api_base = provider_cfg['api_base']

      context = build_ruby_llm_context(provider, api_key, api_base, provider_cfg['settings'] || {})
      yield context, provider
    end

    def embedding_context
      cfg = provider_config
      embedding_cfg = cfg&.dig('embedding') || {}

      provider = embedding_cfg['provider'] || 'openai'
      model = embedding_cfg['model'] || 'text-embedding-3-small'

      api_key = embedding_cfg['api_key'].presence
      api_base = embedding_cfg['api_base'].presence

      if api_key.blank?
        providers_hash = cfg&.dig('providers') || {}
        provider_cfg = providers_hash[provider] || providers_hash['openai'] || {}
        api_key ||= provider_cfg['api_key']
        api_base ||= provider_cfg['api_base']
      end

      context = build_ruby_llm_context(provider, api_key, api_base, {})
      [context, provider, model]
    end

    def disabled_models
      cfg = provider_config
      return [] if cfg.blank?

      cfg['disabled_models'] || []
    end

    def ruby_llm_provider(chatwoot_provider)
      PROVIDER_MAP[chatwoot_provider.to_s] || :openai
    end

    def current_provider
      primary_provider
    end

    def with_api_key(api_key, api_base: nil, provider: nil, &)
      provider_key = provider || primary_provider
      with_provider(provider_key, api_key_override: api_key, &)
    end

    def captain_openai_api_base
      cfg = provider_config
      primary = cfg&.dig('primary_provider') || 'openai'
      providers_hash = cfg&.dig('providers') || {}
      provider_cfg = providers_hash[primary] || {}

      raw = provider_cfg['api_base']
      normalize_api_base(raw.presence || DEFAULT_ENDPOINTS[primary] || 'https://api.openai.com')
    end

    def embedding_openai_credentials
      cfg = provider_config
      embedding_cfg = cfg&.dig('embedding') || {}

      key = embedding_cfg['api_key'].presence
      base = embedding_cfg['api_base'].presence

      if key.blank?
        providers_hash = cfg&.dig('providers') || {}
        provider_cfg = providers_hash['openai'] || {}
        key ||= provider_cfg['api_key']
        base ||= provider_cfg['api_base']
      end

      base = normalize_api_base(base.presence || 'https://api.openai.com')
      [key, base]
    end

    private

    def provider_sym(provider_string)
      PROVIDER_MAP[provider_string.to_s] || :openai
    end

    def build_ruby_llm_context(provider, api_key, api_base, settings = {})
      RubyLLM.context do |config|
        case provider.to_sym
        when :openrouter
          config.openrouter_api_key = api_key
          config.openrouter_api_base = normalize_api_base(api_base) if api_base.present?
        when :anthropic
          config.anthropic_api_key = api_key
          config.anthropic_api_base = normalize_api_base(api_base) if api_base.present?
        when :gemini
          config.gemini_api_key = api_key
        when :ollama
          config.ollama_api_key = api_key if api_key.present?
          config.ollama_api_base = normalize_api_base(api_base, 'ollama') if api_base.present?
        else
          config.openai_api_key = api_key
          config.openai_api_base = normalize_api_base(api_base) if api_base.present?
        end

        config.openai_use_system_role = true
        config.logger = Rails.logger

        registry = Rails.root.join('storage/ruby_llm_models.json').to_s
        config.model_registry_file = registry if File.exist?(registry)
      end
    end

    def normalize_api_base(raw, provider = nil)
      return nil if raw.blank?

      base = raw.is_a?(Hash) ? (raw[:value] || raw['value']).to_s : raw.to_s
      base = base.strip.chomp('/')
      return nil if base.blank?

      return "#{base}/api/v1" if base.match?(%r{\Ahttps?://openrouter\.ai\z}i)

      if provider == 'ollama'
        return base if %r{/v\d+/?$}.match?(base)

        return base
      end

      %r{/v\d+/?$}.match?(base) ? base : "#{base}/v1"
    end

    def migrate_legacy_config
      host = InstallationConfig.find_by(name: 'CAPTAIN_HOST')&.value
      api_key = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
      endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value

      deepseek_key = InstallationConfig.find_by(name: 'CAPTAIN_DEEPSEEK_API_KEY')&.value
      deepseek_endpoint = InstallationConfig.find_by(name: 'CAPTAIN_DEEPSEEK_ENDPOINT')&.value

      qwen_key = InstallationConfig.find_by(name: 'CAPTAIN_QWEN_API_KEY')&.value
      qwen_endpoint = InstallationConfig.find_by(name: 'CAPTAIN_QWEN_ENDPOINT')&.value

      ollama_endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OLLAMA_ENDPOINT')&.value
      ollama_key = InstallationConfig.find_by(name: 'CAPTAIN_OLLAMA_API_KEY')&.value

      openrouter_http_referer = InstallationConfig.find_by(name: 'CAPTAIN_OPENROUTER_HTTP_REFERER')&.value
      openrouter_title = InstallationConfig.find_by(name: 'CAPTAIN_OPENROUTER_TITLE')&.value

      embedding_key = InstallationConfig.find_by(name: 'CAPTAIN_EMBEDDING_OPEN_AI_API_KEY')&.value
      embedding_endpoint = InstallationConfig.find_by(name: 'CAPTAIN_EMBEDDING_OPEN_AI_ENDPOINT')&.value
      embedding_model = InstallationConfig.find_by(name: 'CAPTAIN_EMBEDDING_MODEL')&.value

      primary = 'openai'
      primary = host if host.present? && %w[openrouter deepseek qwen ollama bigmodel.cn].include?(host)
      primary = 'zai' if host == 'bigmodel.cn'

      providers = {}

      providers['openai'] = {
        'enabled' => api_key.present?,
        'api_key' => api_key || '',
        'api_base' => endpoint || DEFAULT_ENDPOINTS['openai'],
        'settings' => {}
      }

      providers['openrouter'] = {
        'enabled' => host == 'openrouter' && api_key.present?,
        'api_key' => host == 'openrouter' ? api_key : '',
        'api_base' => DEFAULT_ENDPOINTS['openrouter'],
        'settings' => {
          'http_referer' => openrouter_http_referer || '',
          'title' => openrouter_title || ''
        }
      }

      providers['anthropic'] = {
        'enabled' => false,
        'api_key' => '',
        'api_base' => DEFAULT_ENDPOINTS['anthropic'],
        'settings' => {}
      }

      providers['gemini'] = {
        'enabled' => false,
        'api_key' => '',
        'api_base' => DEFAULT_ENDPOINTS['gemini'],
        'settings' => {}
      }

      providers['deepseek'] = {
        'enabled' => deepseek_key.present?,
        'api_key' => deepseek_key || '',
        'api_base' => deepseek_endpoint || DEFAULT_ENDPOINTS['deepseek'],
        'settings' => {}
      }

      providers['qwen'] = {
        'enabled' => qwen_key.present?,
        'api_key' => qwen_key || '',
        'api_base' => qwen_endpoint || DEFAULT_ENDPOINTS['qwen'],
        'settings' => {}
      }

      providers['zai'] = {
        'enabled' => host == 'bigmodel.cn' && api_key.present?,
        'api_key' => host == 'bigmodel.cn' ? api_key : '',
        'api_base' => DEFAULT_ENDPOINTS['zai'],
        'settings' => {}
      }

      providers['ollama'] = {
        'enabled' => ollama_endpoint.present?,
        'api_key' => ollama_key || '',
        'api_base' => ollama_endpoint || DEFAULT_ENDPOINTS['ollama'],
        'settings' => {}
      }

      embedding = {
        'provider' => 'openai',
        'model' => embedding_model || 'text-embedding-3-small',
        'api_key' => embedding_key || '',
        'api_base' => embedding_endpoint || ''
      }

      fallback_order = []
      fallback_order << 'openai' if primary != 'openai' && providers['openai']['api_key'].present?

      {
        'primary_provider' => primary,
        'fallback_order' => fallback_order,
        'providers' => providers,
        'embedding' => embedding,
        'disabled_models' => []
      }
    end

    def reset_cache
      @provider_config = nil
    end
  end
end
