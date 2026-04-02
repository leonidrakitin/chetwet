# == Schema Information
#
# Table name: installation_configs
#
#  id               :bigint           not null, primary key
#  locked           :boolean          default(TRUE), not null
#  name             :string           not null
#  serialized_value :jsonb            not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_installation_configs_on_name                 (name) UNIQUE
#  index_installation_configs_on_name_and_created_at  (name,created_at) UNIQUE
#
class InstallationConfig < ApplicationRecord
  # https://stackoverflow.com/questions/72970170/upgrading-to-rails-6-1-6-1-causes-psychdisallowedclass-tried-to-load-unspecif
  # https://discuss.rubyonrails.org/t/cve-2022-32224-possible-rce-escalation-bug-with-serialized-columns-in-active-record/81017
  # FIX ME : fixes breakage of installation config. we need to migrate.
  # Fix configuration in application.rb
  serialize :serialized_value, coder: YAML, type: ActiveSupport::HashWithIndifferentAccess, default: {}.with_indifferent_access

  before_validation :set_lock
  validates :name, presence: true
  validate :saml_sso_users_check, if: -> { name == 'ENABLE_SAML_SSO_LOGIN' }

  # TODO: Get rid of default scope
  # https://stackoverflow.com/a/1834250/939299
  default_scope { order(created_at: :desc) }
  scope :editable, -> { where(locked: false) }

  after_commit :clear_cache
  after_commit :sync_approval_bot_telegram, if: -> { name.in?(%w[APPROVAL_BOT_TELEGRAM_TOKEN APPROVAL_BOT_TELEGRAM_ENABLED]) }

  def value
    serialized_value[:value]
  end

  def value=(value_to_assigned)
    self.serialized_value = {
      value: value_to_assigned
    }.with_indifferent_access
  end

  private

  def set_lock
    self.locked = true if locked.nil?
  end

  def clear_cache
    GlobalConfig.clear_cache
  end

  def sync_approval_bot_telegram
    values = GlobalConfig.get('APPROVAL_BOT_TELEGRAM_TOKEN', 'APPROVAL_BOT_TELEGRAM_ENABLED')
    token = values['APPROVAL_BOT_TELEGRAM_TOKEN']
    enabled = values['APPROVAL_BOT_TELEGRAM_ENABLED'] == true

    Account.find_each do |account|
      config = account.approval_bot_configs.find_or_initialize_by(channel_type: 'telegram')
      config.update!(bot_token: token.presence || config.bot_token, enabled: token.present? && enabled)
    end

    config = ApprovalBotConfig.enabled.find_by(channel_type: 'telegram')
    ApprovalBot::Telegram::WebhookRegistrationService.new(config: config).perform if config
  rescue StandardError => e
    Rails.logger.error("[InstallationConfig] Approval bot sync failed: #{e.message}")
  end

  def saml_sso_users_check
    return unless value == false || value == 'false'
    return unless User.exists?(provider: 'saml')

    errors.add(:base, 'Cannot disable SAML SSO login while users are using SAML authentication')
  end
end
