class SuperAdmin::SettingsController < SuperAdmin::ApplicationController
  def show; end

  # rubocop:disable Rails/I18nLocaleTexts
  def update
    config = InstallationConfig.where(name: 'ENTERPRISE_ENABLED').first_or_create(value: true, locked: false)
    config.value = ActiveModel::Type::Boolean.new.cast(params[:enterprise_enabled])
    config.save!
    redirect_to super_admin_settings_path, notice: 'Enterprise settings updated successfully'
  end

  def refresh
    Internal::CheckNewVersionsJob.perform_now
    redirect_to super_admin_settings_path, notice: 'Instance status refreshed'
  end
  # rubocop:enable Rails/I18nLocaleTexts
end
