class RepurposeResponseBotFlagForCustomTools < ActiveRecord::Migration[7.1]
  def up
    # The response_bot flag (deprecated) has been renamed to custom_tools.
    # Disable it on any accounts that had response_bot enabled so the repurposed
    # flag starts in its intended default-off state.
    # Avoid FlagShihTzu SQL scopes: `feature_flags` is stored as decimal and PostgreSQL
    # rejects `numeric & bigint` without casts.
    Account.find_each(batch_size: 100) do |account|
      next unless account.feature_enabled?('custom_tools')

      account.disable_features(:custom_tools)
      account.save!(validate: false)
    end

    # Remove the stale response_bot entry from ACCOUNT_LEVEL_FEATURE_DEFAULTS.
    # ConfigLoader only adds new flags; it never removes renamed ones.
    # Leaving it would cause NoMethodError in enable_default_features when
    # creating new accounts (feature_response_bot= no longer exists).
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return if config&.value.blank?

    config.value = config.value.reject { |f| f['name'] == 'response_bot' }
    config.save!
    GlobalConfig.clear_cache
  end
end
