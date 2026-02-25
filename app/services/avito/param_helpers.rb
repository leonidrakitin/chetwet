# frozen_string_literal: true

module Avito::ParamHelpers
  # Webhook payload from Avito v3 can come in two forms:
  #
  # Form 1 (wrapped):
  # { payload: { user_id: ..., chat_id: ..., message: { ... } }, event_type: "message" }
  #
  # Form 2 (flat):
  # { user_id: ..., chat_id: ..., message: { ... } }

  def avito_chat_id
    params[:chat_id] || params.dig(:payload, :chat_id)
  end

  def avito_message
    params[:message] || params.dig(:payload, :message) || {}
  end

  def avito_message_id
    avito_message[:id]
  end

  def avito_author_id
    avito_message[:author_id] || params[:author_id]
  end

  def avito_message_type
    avito_message[:type] || 'text'
  end

  def avito_message_content
    avito_message[:content] || {}
  end

  def avito_message_text
    avito_message_content[:text].to_s
  end

  def avito_message_created_at
    avito_message[:created]
  end

  def avito_message_direction
    avito_message[:direction]
  end

  def avito_image_content
    avito_message_content[:image] || avito_message_content[:images]&.first
  end

  def avito_voice_id
    avito_message_content[:voice_id]
  end

  def avito_link_url
    avito_message_content[:url] || avito_message_content[:link]
  end

  def incoming_message?
    return true if avito_message_direction.blank?

    avito_message_direction == 'in'
  end

  def message_params?
    avito_message.present? && avito_chat_id.present? && avito_author_id.present?
  end

  def duplicate_message?
    return false if avito_message_id.blank?

    inbox.messages.exists?(source_id: avito_message_id.to_s)
  end
end
