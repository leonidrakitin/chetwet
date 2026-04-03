# frozen_string_literal: true

module Avito::ParamHelpers
  # Avito v3 webhook delivers a WebhookMessage as params (flat structure):
  # {
  #   id:           "message_id",
  #   chat_id:      "chat_id",
  #   author_id:    123,        # sender
  #   user_id:      456,        # recipient (the other party: buyer when author is seller, seller when author is buyer)
  #   type:         "text",     # message type
  #   content:      { text: "...", image: {...}, voice: {...}, link: {...}, ... },
  #   created:      1571654040,
  #   published_at: "...",
  #   chat_type:    "u2i"
  # }

  def avito_chat_id
    params[:chat_id]
  end

  def avito_message
    params
  end

  def avito_message_id
    params[:id]
  end

  def avito_author_id
    params[:author_id]
  end

  def avito_message_type
    params[:type] || 'text'
  end

  def avito_message_content
    params[:content] || {}
  end

  def avito_message_text
    avito_message_content[:text].to_s
  end

  def avito_message_created_at
    params[:created]
  end

  def avito_message_direction
    params[:direction]
  end

  def avito_image_content
    avito_message_content[:image]
  end

  def avito_voice_id
    avito_message_content.dig(:voice, :voice_id)
  end

  def avito_link_url
    avito_message_content.dig(:link, :url)
  end

  def incoming_message?
    return true if avito_message_direction.blank?

    avito_message_direction == 'in'
  end

  def message_params?
    avito_chat_id.present? && avito_message_id.present? && avito_author_id.present?
  end

  def duplicate_message?
    return false if avito_message_id.blank?

    inbox.messages.exists?(source_id: avito_message_id.to_s)
  end
end
