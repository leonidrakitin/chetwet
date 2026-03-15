# frozen_string_literal: true

# Default locale for the installation (used when locale is blank or invalid).
# Per-request default is set by SwitchLocale from ENV['DEFAULT_LOCALE'] or GlobalConfig (DEFAULT_LOCALE).
Rails.application.config.after_initialize do
  I18n.default_locale = :ru if I18n.available_locales.include?(:ru)
end
