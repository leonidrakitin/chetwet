class Api::V1::Accounts::Captain::PreferencesController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action :authorize_account_update, only: [:update]

  def show
    render json: preferences_payload
  end

  def update
    params_to_update = captain_params
    @current_account.captain_models = params_to_update[:captain_models] if params_to_update[:captain_models]
    @current_account.captain_features = params_to_update[:captain_features] if params_to_update[:captain_features]
    if params_to_update[:message_buffer_seconds].present?
      @current_account.captain_message_buffer_seconds = params_to_update[:message_buffer_seconds].to_i.clamp(1, 30)
    end
    @current_account.save!

    render json: preferences_payload
  end

  private

  def preferences_payload
    provider_cfg = Llm::Config.provider_config
    primary = provider_cfg&.dig('primary_provider') || 'openai'
    providers_hash = provider_cfg&.dig('providers') || {}
    disabled_models = provider_cfg&.dig('disabled_models') || []

    enabled_providers = providers_hash.select { |_, v| v.is_a?(Hash) && v['enabled'] == true }.keys

    {
      providers: Llm::Models.providers,
      models: filter_models_by_enabled_providers(Llm::Models.models, enabled_providers, disabled_models),
      features: features_with_account_preferences(enabled_providers, disabled_models),
      enabled_providers: enabled_providers,
      primary_provider: primary,
      message_buffer_seconds: @current_account.captain_message_buffer_seconds.presence&.to_i || 4
    }
  end

  def filter_models_by_enabled_providers(models, enabled_providers, disabled_models)
    models.select do |model_id, cfg|
      next false if disabled_models.include?(model_id.to_s)

      model_provider = cfg['provider']
      model_hosts = cfg['hosts']

      next true if model_hosts.nil?
      next true if model_hosts.any? { |h| enabled_providers.include?(h) }

      enabled_providers.include?(model_provider)
    end
  end

  def authorize_account_update
    authorize @current_account, :update?
  end

  def captain_params
    permitted = {}
    permitted[:captain_models] = merged_captain_models if params[:captain_models].present?
    permitted[:captain_features] = merged_captain_features if params[:captain_features].present?
    permitted[:message_buffer_seconds] = params[:message_buffer_seconds] if params[:message_buffer_seconds].present?
    permitted
  end

  def merged_captain_models
    existing_models = @current_account.captain_models || {}
    existing_models.merge(permitted_captain_models)
  end

  def merged_captain_features
    existing_features = @current_account.captain_features || {}
    existing_features.merge(permitted_captain_features)
  end

  def permitted_captain_models
    params.require(:captain_models).permit(
      :editor, :assistant, :copilot, :label_suggestion,
      :audio_transcription, :help_center_search
    ).to_h.stringify_keys
  end

  def permitted_captain_features
    params.require(:captain_features).permit(
      :editor, :assistant, :copilot, :label_suggestion,
      :audio_transcription, :help_center_search
    ).to_h.stringify_keys
  end

  def features_with_account_preferences(enabled_providers_arg = nil, disabled_models_arg = nil)
    preferences = Current.account.captain_preferences
    account_features = preferences[:features] || {}
    account_models = preferences[:models] || {}

    provider_cfg = Llm::Config.provider_config
    disabled = disabled_models_arg.presence || provider_cfg&.dig('disabled_models') || []
    enabled = enabled_providers_arg.presence || (provider_cfg&.dig('providers') || {}).select { |_, v| v['enabled'] }.keys

    Llm::Models.feature_keys.index_with do |feature_key|
      config = Llm::Models.feature_config(feature_key)

      filtered_models = config[:models].select do |m|
        next false if disabled.include?(m[:id].to_s)

        model_cfg = Llm::Models.models[m[:id]]
        model_hosts = model_cfg&.dig('hosts')

        next true if model_hosts.nil?
        next true if model_hosts.any? { |h| enabled.include?(h) }

        enabled.include?(m[:provider])
      end

      {
        models: filtered_models,
        default: config[:default],
        enabled: account_features[feature_key] == true,
        selected: account_models[feature_key] || config[:default]
      }
    end
  end
end
