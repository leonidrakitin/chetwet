require 'administrate/field/base'

class CaptainModelsField < Administrate::Field::Base
  FEATURE_ROWS = [
    { key: 'editor', label_key: 'helpers.label.account.captain_model_feature.editor' },
    { key: 'assistant', label_key: 'helpers.label.account.captain_model_feature.assistant' },
    { key: 'copilot', label_key: 'helpers.label.account.captain_model_feature.copilot' }
  ].freeze

  def feature_rows
    FEATURE_ROWS.map do |row|
      row.merge(label: I18n.t(row[:label_key]))
    end
  end

  def captain_host
    @captain_host ||= InstallationConfig.find_by(name: 'CAPTAIN_HOST')&.value
  end

  def models_for_feature(feature_key)
    Llm::Models.feature_config_for_host(feature_key, captain_host)&.dig(:models) || []
  end

  def selected_model_id(feature_key)
    raw = resource.captain_models
    return nil if raw.blank?

    raw[feature_key] || raw[feature_key.to_sym]
  end

  def select_options(feature_key)
    models = models_for_feature(feature_key)
    current = selected_model_id(feature_key)
    opts = models.map { |m| ["#{m[:display_name]} (#{m[:id]})", m[:id].to_s] }
    opts.unshift(["#{current} (saved)", current.to_s]) if current.present? && opts.none? { |(_, id)| id == current.to_s }
    opts.unshift([I18n.t('helpers.label.account.captain_models_default_option'), ''])
    opts
  end
end
