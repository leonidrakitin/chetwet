# frozen_string_literal: true

# == Schema Information
#
# Table name: channel_vk
#
#  id           :bigint           not null, primary key
#  account_id   :integer          not null
#  group_id     :string           not null
#  access_token :string           not null
#  secret       :string
#  group_name   :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_channel_vk_on_group_id  (group_id) UNIQUE
#

class Channel::Vk < ApplicationRecord
  include Channelable

  encrypts :access_token, deterministic: true if Chatwoot.encryption_configured?
  encrypts :refresh_token if Chatwoot.encryption_configured?

  self.table_name = 'channel_vk'
  EDITABLE_ATTRS = [:access_token, :group_id, :secret, :vk_user_id, :refresh_token, :token_expires_at].freeze

  before_validation :ensure_valid_credentials, on: :create
  validates :group_id, presence: true, uniqueness: true
  validates :access_token, presence: true

  def access_token_valid?
    access_token.present? && (token_expires_at.blank? || token_expires_at > Time.current)
  end

  def refresh_token_if_needed!
    return if access_token_valid?
    return if refresh_token.blank?

    result = fetch_refreshed_token
    return unless result

    update_columns(
      access_token: result[:access_token],
      refresh_token: result[:refresh_token],
      token_expires_at: result[:expires_at]
    )
  end

  def name
    'VK'
  end

  def vk_api_url
    'https://api.vk.com/method'
  end

  def send_message_on_vk(message)
    refresh_token_if_needed!
    if peer_id(message).blank?
      Rails.logger.warn "[VK] Cannot send: peer_id missing for conversation #{message.conversation_id}"
      return nil
    end

    return Vk::SendAttachmentsService.new(message: message).perform if message.attachments.present?

    send_message(message) if message.outgoing_content.present?
  end

  def get_vk_user_info(user_id)
    refresh_token_if_needed!
    response = HTTParty.get(
      "#{vk_api_url}/users.get",
      query: {
        user_ids: user_id,
        fields: 'photo_100',
        access_token: access_token,
        v: '5.199'
      }
    )
    return {} unless response.success?

    users = response.parsed_response['response']
    return {} if users.blank?

    users.first.stringify_keys
  end

  def get_vk_profile_image(user_id)
    get_vk_user_info(user_id)['photo_100']
  end

  def get_message_by_id(message_id, peer_id: nil)
    query = { message_ids: message_id, extended: 1, access_token: access_token, v: '5.199' }
    query[:peer_id] = peer_id if peer_id.present?

    response = HTTParty.get(
      "#{vk_api_url}/messages.getById",
      query: query
    )
    return {} unless response.success?

    parsed = response.parsed_response
    return {} if parsed['response'].blank?

    items = parsed.dig('response', 'items') || parsed.dig('response', 'messages')
    items&.first&.stringify_keys || {}
  end

  def process_error(message, response)
    error = response.parsed_response['error']
    return unless error

    message.external_error = "#{error['error_code']}, #{error['error_msg']}"
    message.status = :failed
    message.save!
  end

  def peer_id(message)
    conv = message.conversation
    conv.additional_attributes&.dig('peer_id') || conv.additional_attributes&.dig(:peer_id)
  end

  def reply_to_message_id(message)
    message.content_attributes['in_reply_to_external_id']
  end

  def mark_as_read(peer_id)
    HTTParty.post(
      "#{vk_api_url}/messages.markAsRead",
      body: { peer_id: peer_id, access_token: access_token, v: '5.199' }
    )
  end

  def send_typing_activity(peer_id)
    HTTParty.post(
      "#{vk_api_url}/messages.setActivity",
      body: { peer_id: peer_id, type: 'typing', access_token: access_token, v: '5.199' }
    )
  end

  def send_message(message)
    body = {
      peer_id: peer_id(message),
      message: message.outgoing_content,
      random_id: SecureRandom.random_number(2**31)
    }
    body[:reply_to] = reply_to_message_id(message) if reply_to_message_id(message)

    response = HTTParty.post(
      "#{vk_api_url}/messages.send",
      body: body.merge(access_token: access_token, v: '5.199')
    )

    process_error(message, response)
    response.parsed_response['response'] if response.success?
  end

  private

  def fetch_refreshed_token
    response = HTTParty.post(
      'https://id.vk.com/oauth2/token',
      body: {
        client_id: ENV.fetch('VK_CLIENT_ID', nil),
        client_secret: ENV.fetch('VK_CLIENT_SECRET', nil),
        refresh_token: refresh_token,
        grant_type: 'refresh_token'
      }
    )
    return nil unless response.success?

    parsed = response.parsed_response
    return nil if parsed['access_token'].blank?

    {
      access_token: parsed['access_token'],
      refresh_token: parsed['refresh_token'] || refresh_token,
      expires_at: Time.current + parsed['expires_in'].to_i.seconds
    }
  rescue StandardError => e
    Rails.logger.error "[VK] refresh token error: #{e.message}"
    nil
  end

  def ensure_valid_credentials
    normalized_group_id = group_id.to_s.sub(/\A-/, '')
    response = HTTParty.get(
      "#{vk_api_url}/groups.getById",
      query: {
        group_id: normalized_group_id,
        access_token: access_token,
        v: '5.199'
      }
    )

    unless response.success?
      errors.add(:access_token, 'invalid token or network error')
      return
    end

    parsed = response.parsed_response
    if (err = parsed['error'])
      msg = err['error_msg'] || 'unknown error'
      Rails.logger.info "[VK] groups.getById error: #{msg} (code: #{err['error_code']})"
      errors.add(:base, msg)
      return
    end

    group = parsed.dig('response', 'groups', 0) || parsed.dig('response', 0)
    if group.blank?
      Rails.logger.info "[VK] groups.getById empty response for group_id=#{normalized_group_id}"
      errors.add(:base, I18n.t('errors.channel.vk.group_not_found'))
      return
    end

    self.group_name = group['name']
  end
end
