# frozen_string_literal: true

module Vk::ParamHelpers
  def message_params
    params[:message] || params
  end

  def message_params?
    message_params.present?
  end

  def vk_params_from_id
    message_params[:from_id]
  end

  def vk_params_peer_id
    message_params[:peer_id]
  end

  def vk_params_message_content
    message_params[:text].to_s || message_params[:body].to_s
  end

  def vk_params_message_id
    message_params[:id] || message_params[:conversation_message_id]
  end

  def vk_params_attachments
    message_params[:attachments] || []
  end

  def vk_params_content_attributes
    reply_to = message_params[:reply_message]&.dig('id')
    return { 'in_reply_to_external_id' => reply_to } if reply_to

    {}
  end
end
