module Llm::Models
  CONFIG = YAML.load_file(Rails.root.join('config/llm.yml')).freeze
  HOSTS = %w[openrouter openai deepseek bigmodel.cn].freeze

  class << self
    def providers = CONFIG['providers']
    def models = CONFIG['models']
    def features = CONFIG['features']
    def pricing = CONFIG['pricing']
    def feature_keys = CONFIG['features'].keys
    def hosts = HOSTS

    def default_model_for(feature)
      CONFIG.dig('features', feature.to_s, 'default')
    end

    def models_for(feature)
      CONFIG.dig('features', feature.to_s, 'models') || []
    end

    def valid_model_for?(feature, model_name)
      models_for(feature).include?(model_name.to_s)
    end

    def models_for_host(host)
      return models if host.blank?

      models.select { |_id, cfg| cfg['hosts'].nil? || cfg['hosts'].include?(host) }
    end

    def pricing_for(model_name)
      return nil if model_name.blank?

      pricing&.dig(model_name.to_s) || models&.dig(model_name.to_s, 'pricing')
    end

    def feature_config(feature_key)
      feature = features[feature_key.to_s]
      return nil unless feature

      {
        models: feature['models'].map do |model_name|
          model = models[model_name]
          {
            id: model_name,
            display_name: model['display_name'],
            provider: model['provider'],
            coming_soon: model['coming_soon'],
            credit_multiplier: model['credit_multiplier']
          }
        end,
        default: feature['default']
      }
    end

    def feature_config_for_host(feature_key, host)
      cfg = feature_config(feature_key)
      return cfg if host.blank? || cfg.nil?

      filtered = cfg[:models].select do |m|
        model_cfg = models[m[:id]]
        model_cfg && (model_cfg['hosts'].nil? || model_cfg['hosts'].include?(host))
      end
      cfg.merge(models: filtered)
    end

    def available_models(provider_config: nil)
      return models if provider_config.blank?

      providers_hash = provider_config['providers'] || {}
      disabled = provider_config['disabled_models'] || []

      enabled_providers = providers_hash.select { |_, v| v.is_a?(Hash) && v['enabled'] == true }.keys

      models.select do |model_id, cfg|
        next false if disabled.include?(model_id.to_s)

        model_provider = cfg['provider']
        model_hosts = cfg['hosts']

        next true if model_hosts.nil?
        next true if model_hosts.any? { |h| enabled_providers.include?(h) }

        enabled_providers.include?(model_provider)
      end
    end

    def ruby_llm_provider_for(chatwoot_provider)
      Llm::Config.ruby_llm_provider(chatwoot_provider)
    end
  end
end
