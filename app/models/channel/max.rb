# frozen_string_literal: true

# == Schema Information
#
# Table name: channel_max
#
#  id         :bigint           not null, primary key
#  bot_name   :string
#  bot_token  :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :integer          not null
#
# Indexes
#
#  index_channel_max_on_bot_token  (bot_token) UNIQUE
#

class Channel::Max < ApplicationRecord
  include Channelable

  encrypts :bot_token, deterministic: true if Chatwoot.encryption_configured?

  self.table_name = 'channel_max'
  EDITABLE_ATTRS = [:bot_token].freeze

  MAX_API_URL = 'https://platform-api.max.ru'

  before_validation :ensure_valid_bot_token, on: :create
  validates :bot_token, presence: true, uniqueness: true
  after_commit :subscribe_to_webhooks, on: :create

  def name
    'MAX'
  end

  def max_api_url
    MAX_API_URL
  end

  def api_headers
    { 'Authorization' => bot_token, 'Content-Type' => 'application/json' }
  end

  def send_message_on_max(message)
    chat_id = conversation_chat_id(message)
    if chat_id.blank?
      Rails.logger.warn "[MAX] Cannot send: chat_id missing for conversation #{message.conversation_id}"
      return nil
    end

    send_text_message(chat_id, message) if message.outgoing_content.present?
  end

  def conversation_chat_id(message)
    message.conversation.additional_attributes&.dig('max_chat_id')
  end

  def process_error(message, response)
    return if response.success?

    message.external_error = response.parsed_response.to_s
    message.status = :failed
    message.save!
  end

  private

  def ensure_valid_bot_token
    response = HTTParty.get(
      "#{max_api_url}/me",
      headers: { 'Authorization' => bot_token }
    )
    unless response.success?
      errors.add(:bot_token, 'invalid token')
      return
    end

    self.bot_name = response.parsed_response['name']
  end

  def subscribe_to_webhooks
    webhook_url = "#{ENV.fetch('FRONTEND_URL', nil)}/webhooks/max/#{account_id}/#{inbox.id}"
    HTTParty.post(
      "#{max_api_url}/subscriptions",
      headers: api_headers,
      body: {
        url: webhook_url,
        update_types: %w[message_created message_callback bot_started]
      }.to_json
    )
  rescue StandardError => e
    Rails.logger.error "[MAX] Failed to subscribe to webhooks: #{e.message}"
  end

  def send_text_message(chat_id, message)
    body = { text: message.outgoing_content }
    body[:attachments] = inline_keyboard(message) if message.content_type == 'input_select'

    response = HTTParty.post(
      "#{max_api_url}/messages",
      query: { chat_id: chat_id },
      headers: api_headers,
      body: body.to_json
    )

    process_error(message, response)
    response.parsed_response.dig('message', 'body', 'mid') if response.success?
  end

  def inline_keyboard(message)
    buttons = message.content_attributes['items'].map do |item|
      [{ type: 'callback', text: item['title'], payload: item['value'] }]
    end
    [{ type: 'inline_keyboard', payload: { buttons: buttons } }]
  end
end
