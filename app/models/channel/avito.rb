# frozen_string_literal: true

# == Schema Information
#
# Table name: channel_avito
#
#  id               :bigint           not null, primary key
#  account_id       :integer          not null
#  client_id        :string           not null
#  client_secret    :string           not null
#  avito_user_id    :bigint
#  access_token     :string
#  token_expires_at :datetime
#  avito_user_name  :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_channel_avito_on_client_id      (client_id) UNIQUE
#  index_channel_avito_on_avito_user_id  (avito_user_id)
#

class Channel::Avito < ApplicationRecord
  include Channelable

  encrypts :client_secret if Chatwoot.encryption_configured?
  encrypts :access_token if Chatwoot.encryption_configured?

  self.table_name = 'channel_avito'
  EDITABLE_ATTRS = [:client_id, :client_secret].freeze

  AVITO_API_BASE = 'https://api.avito.ru'

  before_validation :fetch_and_store_token, on: :create
  after_create :setup_webhook
  before_destroy :remove_webhook

  validates :client_id, presence: true, uniqueness: true
  validates :client_secret, presence: true
  validates :avito_user_id, presence: true

  def name
    'Avito'
  end

  def avito_api_url
    AVITO_API_BASE
  end

  def access_token_valid?
    access_token.present? && token_expires_at.present? && token_expires_at > Time.current
  end

  def refresh_token_if_needed!
    return if access_token_valid?

    result = fetch_access_token
    return unless result

    update_columns(access_token: result[:token], token_expires_at: result[:expires_at])
  end

  def send_message_on_avito(message)
    refresh_token_if_needed!
    return nil if chat_id(message).blank?

    if message.attachments.present?
      Avito::SendAttachmentsService.new(message: message).perform
    elsif message.outgoing_content.present?
      send_text_message(message)
    end
  end

  def chat_id(message)
    conv = message.conversation
    conv.additional_attributes&.dig('chat_id') || conv.additional_attributes&.dig(:chat_id)
  end

  def reply_to_message_id(message)
    message.content_attributes['in_reply_to_external_id']
  end

  def get_chat_user_info(chat_id)
    refresh_token_if_needed!

    response = HTTParty.get(
      "#{AVITO_API_BASE}/messenger/v2/accounts/#{avito_user_id}/chats/#{chat_id}",
      headers: auth_headers
    )
    return {} unless response.success?

    parsed = response.parsed_response
    users = parsed['users'] || []
    # Return users list excluding ourselves (filter by avito_user_id)
    other_users = users.reject { |u| u['id'].to_i == avito_user_id.to_i }
    other_users.first || users.first || {}
  rescue StandardError => e
    Rails.logger.error "[Avito] get_chat_user_info error: #{e.message}"
    {}
  end

  def get_voice_file_url(voice_id)
    refresh_token_if_needed!

    response = HTTParty.get(
      "#{AVITO_API_BASE}/messenger/v1/accounts/#{avito_user_id}/getVoiceFiles",
      query: { 'voice_ids[]' => voice_id },
      headers: auth_headers
    )
    return nil unless response.success?

    urls = response.parsed_response['voices_urls'] || {}
    urls[voice_id]
  rescue StandardError => e
    Rails.logger.error "[Avito] get_voice_file_url error: #{e.message}"
    nil
  end

  def upload_image(file_path)
    refresh_token_if_needed!

    response = HTTParty.post(
      "#{AVITO_API_BASE}/messenger/v1/accounts/#{avito_user_id}/uploadImages",
      headers: auth_headers,
      body: { 'uploadfile[]' => File.open(file_path, 'rb') },
      multipart: true
    )
    return nil unless response.success?

    parsed = response.parsed_response
    # Returns hash like { "image_key": { "1280x960": "url", ... } }
    parsed.keys.first
  rescue StandardError => e
    Rails.logger.error "[Avito] upload_image error: #{e.message}"
    nil
  end

  def send_image_message(chat_id_val, image_id)
    refresh_token_if_needed!

    response = HTTParty.post(
      "#{AVITO_API_BASE}/messenger/v1/accounts/#{avito_user_id}/chats/#{chat_id_val}/messages/image",
      headers: auth_headers.merge('Content-Type' => 'application/json'),
      body: { image_id: image_id }.to_json
    )
    return nil unless response.success?

    response.parsed_response['id']
  rescue StandardError => e
    Rails.logger.error "[Avito] send_image_message error: #{e.message}"
    nil
  end

  def mark_chat_as_read(chat_id_val)
    refresh_token_if_needed!

    HTTParty.post(
      "#{AVITO_API_BASE}/messenger/v1/accounts/#{avito_user_id}/chats/#{chat_id_val}/read",
      headers: auth_headers
    )
  rescue StandardError => e
    Rails.logger.warn "[Avito] mark_chat_as_read error: #{e.message}"
  end

  def auth_headers
    { 'Authorization' => "Bearer #{access_token}" }
  end

  private

  def fetch_and_store_token
    result = fetch_access_token
    unless result
      errors.add(:client_id, I18n.t('errors.channel.avito.invalid_credentials'))
      return
    end

    self.access_token = result[:token]
    self.token_expires_at = result[:expires_at]

    user_info = fetch_user_info
    unless user_info
      errors.add(:client_id, I18n.t('errors.channel.avito.user_info_failed'))
      return
    end

    self.avito_user_id = user_info['id']
    self.avito_user_name = user_info['name'] || user_info['email'] || "Avito #{user_info['id']}"
  end

  def fetch_access_token
    response = HTTParty.post(
      "#{AVITO_API_BASE}/token",
      body: {
        grant_type: 'client_credentials',
        client_id: client_id,
        client_secret: client_secret
      }
    )

    return nil unless response.success?

    parsed = response.parsed_response
    return nil if parsed['access_token'].blank?

    {
      token: parsed['access_token'],
      expires_at: Time.current + parsed['expires_in'].to_i.seconds
    }
  rescue StandardError => e
    Rails.logger.error "[Avito] fetch_access_token error: #{e.message}"
    nil
  end

  def fetch_user_info
    response = HTTParty.get(
      "#{AVITO_API_BASE}/core/v1/accounts/self",
      headers: { 'Authorization' => "Bearer #{access_token}" }
    )
    return nil unless response.success?

    response.parsed_response
  rescue StandardError => e
    Rails.logger.error "[Avito] fetch_user_info error: #{e.message}"
    nil
  end

  def setup_webhook
    refresh_token_if_needed!
    webhook_url = "#{ENV.fetch('FRONTEND_URL', nil)}/webhooks/avito/#{avito_user_id}"

    response = HTTParty.post(
      "#{AVITO_API_BASE}/messenger/v3/webhook",
      headers: auth_headers.merge('Content-Type' => 'application/json'),
      body: { url: webhook_url }.to_json
    )

    Rails.logger.warn "[Avito] Webhook setup failed: #{response.parsed_response}" unless response.success?
  rescue StandardError => e
    Rails.logger.error "[Avito] setup_webhook error: #{e.message}"
  end

  def remove_webhook
    refresh_token_if_needed!
    webhook_url = "#{ENV.fetch('FRONTEND_URL', nil)}/webhooks/avito/#{avito_user_id}"

    HTTParty.post(
      "#{AVITO_API_BASE}/messenger/v1/webhook/unsubscribe",
      headers: auth_headers.merge('Content-Type' => 'application/json'),
      body: { url: webhook_url }.to_json
    )
  rescue StandardError => e
    Rails.logger.error "[Avito] remove_webhook error: #{e.message}"
  end

  def send_text_message(message)
    response = HTTParty.post(
      "#{AVITO_API_BASE}/messenger/v1/accounts/#{avito_user_id}/chats/#{chat_id(message)}/messages",
      headers: auth_headers.merge('Content-Type' => 'application/json'),
      body: {
        message: {
          text: message.outgoing_content,
          type: 'text'
        }
      }.to_json
    )

    unless response.success?
      Rails.logger.warn "[Avito] send_text_message failed: #{response.parsed_response}"
      return nil
    end

    response.parsed_response['id']
  rescue StandardError => e
    Rails.logger.error "[Avito] send_text_message error: #{e.message}"
    nil
  end
end
