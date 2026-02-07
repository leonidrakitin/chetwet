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

  self.table_name = 'channel_vk'
  EDITABLE_ATTRS = [:access_token, :group_id, :secret].freeze

  before_validation :ensure_valid_credentials, on: :create
  validates :group_id, presence: true, uniqueness: true
  validates :access_token, presence: true

  def name
    'VK'
  end

  def vk_api_url
    'https://api.vk.com/method'
  end

  def send_message_on_vk(message)
    return Vk::SendAttachmentsService.new(message: message).perform if message.attachments.present?

    send_message(message) if message.outgoing_content.present?
  end

  def get_vk_user_info(user_id)
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
    message.conversation[:additional_attributes]['peer_id']
  end

  def reply_to_message_id(message)
    message.content_attributes['in_reply_to_external_id']
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
