class SuperAdmin::SettingsController < SuperAdmin::ApplicationController
  def show; end

  def refresh
    # Internal::CheckNewVersionsJob disabled
    redirect_to super_admin_settings_path, notice: 'Instance sync is disabled'
  end

  def toggle_feature
    feature_key = params[:feature_key]
    result = SuperAdmin::FeaturesHelper.toggle_feature!(feature_key)

    if result
      features = SuperAdmin::FeaturesHelper.available_features
      feature_name = features.dig(feature_key, :name) || feature_key
      redirect_to super_admin_settings_path, notice: "Feature \"#{feature_name}\" has been updated."
    else
      redirect_to super_admin_settings_path, alert: 'Could not toggle feature.'
    end
  end
end
