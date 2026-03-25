module Captain::FeatureFlagsHelper
  # Feature flag management for Z.AI integration rollout

  ZAI_PROVIDER_FLAG = 'zai_provider'
  ZAI_ENABLED_FLAG = 'zai_enabled'
  ZAI_VISION_FLAG = 'zai_vision'
  ZAI_THINKING_MODE_FLAG = 'zai_thinking_mode'

  class << self
    # Check if Z.AI provider is enabled for account
    def zai_provider_enabled?(account_id)
      return false unless account_id

      config = InstallationConfig.find_by(name: 'CAPTAIN_ZAI_PROVIDER_ENABLED')
      return config.value == 'true' if config

      # Default to disabled unless explicitly enabled
      false
    end

    # Check if specific account uses Z.AI (based on global flag + rollout percentage)
    def use_zai_for_account?(account)
      return false unless account

      zai_provider_enabled?(account.id) && account_in_rollout?(account.id)
    end

    # Get configured Z.AI model or fallback
    def zai_model_for_account(_account_id)
      model = InstallationConfig.find_by(name: 'CAPTAIN_ZAI_MODEL')&.value
      model || LlmConstants::DEFAULT_MODEL
    end

    # Check if vision is enabled
    def vision_enabled?(account_id)
      return false unless account_id

      config = InstallationConfig.find_by(name: 'CAPTAIN_ZAI_VISION_ENABLED')
      return config.value == 'true' if config

      # Default to enabled if Z.AI is enabled
      zai_provider_enabled?(account_id)
    rescue StandardError
      false
    end

    # Check if Thinking Mode is enabled
    def thinking_mode_enabled?(account_id)
      return false unless account_id

      config = InstallationConfig.find_by(name: 'CAPTAIN_ZAI_THINKING_MODE_ENABLED')
      return config.value == 'true' if config

      # Default to enabled if Z.AI is enabled
      zai_provider_enabled?(account_id)
    rescue StandardError
      false
    end

    # Get rollout percentage (0-100) for gradual deployment
    def zai_rollout_percentage
      config = InstallationConfig.find_by(name: 'CAPTAIN_ZAI_ROLLOUT_PERCENTAGE')
      (config&.value.to_i) || 0
    end

    # Check if account is in rollout percentage
    def account_in_rollout?(account_id)
      percentage = zai_rollout_percentage
      return true if percentage >= 100

      # Use account_id hash for consistent bucketing
      bucket = (account_id.to_i % 100)
      bucket < percentage
    end

    # Enable Z.AI provider system-wide
    def enable_zai_provider!
      InstallationConfig.find_or_create_by(name: 'CAPTAIN_ZAI_PROVIDER_ENABLED')
                        .update(value: 'true')
    end

    # Disable Z.AI provider system-wide
    def disable_zai_provider!
      InstallationConfig.find_or_create_by(name: 'CAPTAIN_ZAI_PROVIDER_ENABLED')
                        .update(value: 'false')
    end

    # Set rollout percentage
    def set_rollout_percentage(percentage)
      raise ArgumentError, 'Percentage must be 0-100' if percentage < 0 || percentage > 100

      InstallationConfig.find_or_create_by(name: 'CAPTAIN_ZAI_ROLLOUT_PERCENTAGE')
                        .update(value: percentage.to_s)
    end

    # Recommended rollout stages
    def rollout_stages
      {
        testing: 0,       # Internal testing only
        early_access: 10, # 10% of accounts
        beta: 25,         # 25% of accounts
        staging: 50,      # 50% of accounts
        general: 100      # All accounts
      }
    end
  end
end
