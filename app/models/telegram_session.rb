# == Schema Information
#
# Table name: telegram_sessions
#
#  id                     :bigint           not null, primary key
#  api_hash               :string           not null
#  api_id                 :string           not null
#  auth_state             :string
#  encrypted_session_data :text
#  last_error             :text
#  metadata               :jsonb            not null
#  phone_number           :string           not null
#  status                 :integer          default("authenticating"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  inbox_id               :bigint           not null
#  user_id                :bigint           not null
#

class TelegramSession < ApplicationRecord
  enum :status, { authenticating: 0, active: 1, disconnected: 2 }, default: :authenticating

  belongs_to :user
  belongs_to :inbox

  validates :phone_number, presence: true
  validates :api_id, presence: true
  validates :api_hash, presence: true
  validates :inbox_id, uniqueness: true

  encrypts :api_id, :api_hash if Chatwoot.encryption_configured?

  store_accessor :metadata, :telegram_user_id, :telegram_username, :last_synced_at

  after_commit :ensure_event_worker, on: %i[create update]

  def directory_key
    "telegram-session-#{id || SecureRandom.hex(6)}"
  end

  def session_data
    return {} if encrypted_session_data.blank?

    Telegram::TdlibConfig.encryptor.decrypt_and_verify(encrypted_session_data)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    {}
  end

  def session_data=(value)
    payload = value.is_a?(Hash) ? value : {}
    self.encrypted_session_data = Telegram::TdlibConfig.encryptor.encrypt_and_sign(payload)
  end

  def persist_session_snapshot!(payload = {})
    # Храним только метаданные и пути TDLib, чтобы не светить сырые данные сессии в БД.
    self.session_data = {
      phone_number: phone_number,
      auth_state: auth_state,
      status: status,
      telegram_user_id: telegram_user_id,
      telegram_username: telegram_username,
      database_directory: Telegram::TdlibConfig.database_directory(self).to_s,
      files_directory: Telegram::TdlibConfig.files_directory(self).to_s,
      updated_at: Time.current.to_i
    }.merge(payload.deep_stringify_keys)
    save!
  end

  def active_for_delivery?
    active? && inbox.channel_type == 'Channel::TelegramPersonal'
  end

  private

  def ensure_event_worker
    return unless inbox.channel_type == 'Channel::TelegramPersonal'
    return unless active?

    TdlibEventWorker.perform_later(id)
  end
end
