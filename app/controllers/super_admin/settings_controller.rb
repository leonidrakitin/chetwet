class SuperAdmin::SettingsController < SuperAdmin::ApplicationController
  def show; end

  def refresh
    # Internal::CheckNewVersionsJob disabled
    redirect_to super_admin_settings_path, notice: 'Instance sync is disabled'
  end
end
