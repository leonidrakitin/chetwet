class SuperAdmin::AppConfigsController < SuperAdmin::ApplicationController
  APP_CONFIG_NAME_GROUPS = {
    'facebook' => %w[FB_APP_ID FB_VERIFY_TOKEN FB_APP_SECRET IG_VERIFY_TOKEN FACEBOOK_API_VERSION ENABLE_MESSENGER_CHANNEL_HUMAN_AGENT],
    'shopify' => %w[SHOPIFY_CLIENT_ID SHOPIFY_CLIENT_SECRET],
    'microsoft' => %w[AZURE_APP_ID AZURE_APP_SECRET],
    'email' => %w[MAILER_INBOUND_EMAIL_DOMAIN ACCOUNT_EMAILS_LIMIT ACCOUNT_EMAILS_PLAN_LIMITS],
    'linear' => %w[LINEAR_CLIENT_ID LINEAR_CLIENT_SECRET],
    'slack' => %w[SLACK_CLIENT_ID SLACK_CLIENT_SECRET],
    'instagram' => %w[INSTAGRAM_APP_ID INSTAGRAM_APP_SECRET INSTAGRAM_VERIFY_TOKEN INSTAGRAM_API_VERSION ENABLE_INSTAGRAM_CHANNEL_HUMAN_AGENT],
    'tiktok' => %w[TIKTOK_APP_ID TIKTOK_APP_SECRET TIKTOK_API_VERSION],
    'telegram' => %w[APPROVAL_BOT_TELEGRAM_TOKEN APPROVAL_BOT_TELEGRAM_ENABLED],
    'telegram_personal' => %w[ENABLE_TELEGRAM_PERSONAL_CHANNEL TELEGRAM_PERSONAL_API_ID TELEGRAM_PERSONAL_API_HASH],
    'whatsapp_embedded' => %w[WHATSAPP_APP_ID WHATSAPP_APP_SECRET WHATSAPP_CONFIGURATION_ID WHATSAPP_API_VERSION],
    'notion' => %w[NOTION_CLIENT_ID NOTION_CLIENT_SECRET],
    'google' => %w[GOOGLE_OAUTH_CLIENT_ID GOOGLE_OAUTH_CLIENT_SECRET GOOGLE_OAUTH_REDIRECT_URI ENABLE_GOOGLE_OAUTH_LOGIN],
    'vk_id' => %w[VK_ID_CLIENT_ID VK_ID_CLIENT_SECRET VK_ID_REDIRECT_URI ENABLE_VK_ID_OAUTH_LOGIN],
    'yandex' => %w[YANDEX_OAUTH_CLIENT_ID YANDEX_OAUTH_CLIENT_SECRET YANDEX_OAUTH_CALLBACK_URL ENABLE_YANDEX_OAUTH_LOGIN],
    'captain' => %w[CAPTAIN_PROVIDERS CAPTAIN_FIRECRAWL_API_KEY],
    'migrations' => %w[TELEGRAM_MIGRATION_MAX_CONCURRENCY],
    'yclients' => %w[
      YCLIENTS_MARKETPLACE_PARTNER_TOKEN
      YCLIENTS_SYSTEM_USER_ID
      YCLIENTS_MARKETPLACE_CALLBACK_URL
      YCLIENTS_MARKETPLACE_APPLICATION_ID
      YCLIENTS_MARKETPLACE_WEBHOOK_SECRET
      YCLIENTS_USER_TOKEN
    ]
  }.freeze

  before_action :set_config
  before_action :allowed_configs
  before_action :set_captain_config, only: %i[show create], if: -> { @config == 'captain' }

  def show
    @app_config = InstallationConfig.where(name: @allowed_configs)
                                    .pluck(:name, :serialized_value)
                                    .map { |name, serialized_value| [name, serialized_value['value']] }
                                    .to_h
    @installation_configs = ConfigLoader.new.general_configs.each_with_object({}) do |config_hash, result|
      result[config_hash['name']] = config_hash.except('name')
    end
  end

  def create
    if @config == 'captain'
      create_captain_config
    else
      create_generic_config
    end
  end

  private

  def set_config
    @config = params[:config] || 'general'
  end

  def allowed_configs
    @allowed_configs = APP_CONFIG_NAME_GROUPS.fetch(
      @config,
      %w[ENABLE_ACCOUNT_SIGNUP FIREBASE_PROJECT_ID FIREBASE_CREDENTIALS WEBHOOK_TIMEOUT MAXIMUM_FILE_UPLOAD_SIZE WIDGET_TOKEN_EXPIRY]
    )
  end

  def set_captain_config
    @captain_providers = load_captain_providers
    @firecrawl_key = InstallationConfig.find_by(name: 'CAPTAIN_FIRECRAWL_API_KEY')&.value
  end

  def load_captain_providers
    raw = InstallationConfig.find_by(name: 'CAPTAIN_PROVIDERS')&.value
    return default_captain_providers if raw.blank?

    raw
  end

  def default_captain_providers
    {
      'primary_provider' => 'openai',
      'fallback_order' => [],
      'providers' => {
        'openai' => { 'enabled' => false, 'api_key' => '', 'api_base' => 'https://api.openai.com', 'settings' => {} },
        'openrouter' => { 'enabled' => false, 'api_key' => '', 'api_base' => 'https://openrouter.ai',
                          'settings' => { 'http_referer' => '', 'title' => '' } },
        'anthropic' => { 'enabled' => false, 'api_key' => '', 'api_base' => 'https://api.anthropic.com', 'settings' => {} },
        'gemini' => { 'enabled' => false, 'api_key' => '', 'api_base' => 'https://generativelanguage.googleapis.com', 'settings' => {} },
        'deepseek' => { 'enabled' => false, 'api_key' => '', 'api_base' => 'https://api.deepseek.com', 'settings' => {} },
        'qwen' => { 'enabled' => false, 'api_key' => '', 'api_base' => 'https://dashscope.aliyuncs.com/compatible-mode', 'settings' => {} },
        'zai' => { 'enabled' => false, 'api_key' => '', 'api_base' => 'https://open.bigmodel.cn', 'settings' => {} },
        'ollama' => { 'enabled' => false, 'api_key' => '', 'api_base' => 'http://localhost:11434', 'settings' => {} }
      },
      'embedding' => { 'provider' => 'openai', 'model' => 'text-embedding-3-small', 'api_key' => '', 'api_base' => '' },
      'disabled_models' => []
    }
  end

  def create_captain_config
    providers_config = build_providers_config_from_params

    record = InstallationConfig.find_or_initialize_by(name: 'CAPTAIN_PROVIDERS')
    record.value = providers_config
    record.locked = false

    errors = record.errors.full_messages unless record.save

    firecrawl = params.dig(:captain, :firecrawl_api_key)
    if firecrawl.present?
      fr = InstallationConfig.find_or_initialize_by(name: 'CAPTAIN_FIRECRAWL_API_KEY')
      fr.value = firecrawl
      fr.locked = false
      errors ||= []
      errors.concat(fr.errors.full_messages) unless fr.save
    end

    if errors&.any?
      redirect_to super_admin_app_config_path(config: @config), alert: errors.join(', ')
    else
      Llm::Config.instance_variable_set(:@provider_config, nil)
      Llm::Config.apply_to_globals!
      redirect_to super_admin_settings_path, notice: "App Configs - #{@config.titleize} updated successfully"
    end
  end

  def build_providers_config_from_params
    captain_params = params[:captain] || {}

    primary = captain_params[:primary_provider] || 'openai'
    fallback_order = (captain_params[:fallback_order] || '').split(',').map(&:strip).reject(&:blank?)

    providers = {}
    %w[openai openrouter anthropic gemini deepseek qwen zai ollama].each do |provider_name|
      provider_data = captain_params[:providers]&.dig(provider_name) || {}
      providers[provider_name] = {
        'enabled' => provider_data[:enabled] == '1',
        'api_key' => provider_data[:api_key] || '',
        'api_base' => provider_data[:api_base] || Llm::Config::DEFAULT_ENDPOINTS[provider_name] || '',
        'settings' => extract_provider_settings(provider_name, provider_data)
      }
    end

    embedding_data = captain_params[:embedding] || {}
    embedding = {
      'provider' => embedding_data[:provider] || 'openai',
      'model' => embedding_data[:model] || 'text-embedding-3-small',
      'api_key' => embedding_data[:api_key] || '',
      'api_base' => embedding_data[:api_base] || ''
    }

    disabled_models = (captain_params[:disabled_models] || '').split(',').map(&:strip).reject(&:blank?)

    {
      'primary_provider' => primary,
      'fallback_order' => fallback_order,
      'providers' => providers,
      'embedding' => embedding,
      'disabled_models' => disabled_models
    }
  end

  def extract_provider_settings(provider_name, provider_data)
    settings = {}
    if provider_name == 'openrouter'
      settings['http_referer'] = provider_data.dig(:settings, :http_referer) || ''
      settings['title'] = provider_data.dig(:settings, :title) || ''
    end
    settings
  end

  def create_generic_config
    errors = []
    params['app_config'].each do |key, value|
      next unless @allowed_configs.include?(key)

      i = InstallationConfig.where(name: key).first_or_create(value: value, locked: false)
      i.value = value
      errors.concat(i.errors.full_messages) unless i.save
    end

    if errors.any?
      redirect_to super_admin_app_config_path(config: @config), alert: errors.join(', ')
    else
      redirect_to super_admin_settings_path, notice: "App Configs - #{@config.titleize} updated successfully"
    end
  end
end

SuperAdmin::AppConfigsController.prepend_mod_with('SuperAdmin::AppConfigsController')
