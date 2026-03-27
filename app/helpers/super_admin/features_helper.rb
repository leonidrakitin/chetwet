module SuperAdmin::FeaturesHelper
  OVERRIDE_PREFIX = 'FEATURE_ENABLED_'.freeze

  def self.available_features
    yaml_features = YAML.load(ERB.new(Rails.root.join('app/helpers/super_admin/features.yml').read).result).with_indifferent_access
    overrides = feature_overrides

    yaml_features.each_with_object({}) do |(key, attrs), result|
      result[key] = attrs.dup
      next if attrs[:enterprise]

      result[key][:toggleable] = true
      override_key = "#{OVERRIDE_PREFIX}#{key.upcase}"
      result[key][:enabled] = overrides[override_key] unless overrides[override_key].nil?
    end
  end

  def self.feature_overrides
    InstallationConfig.where('name LIKE ?', "#{OVERRIDE_PREFIX}%").each_with_object({}) do |config, hash|
      hash[config.name] = config.value
    end
  end

  def self.toggle_feature!(feature_key)
    features = available_features
    return false unless features[feature_key]
    return false if features[feature_key][:enterprise]

    config_name = "#{OVERRIDE_PREFIX}#{feature_key.upcase}"
    config = InstallationConfig.find_or_initialize_by(name: config_name)
    config.value = !features[feature_key][:enabled]
    config.locked = false
    config.save!
    true
  end
end
