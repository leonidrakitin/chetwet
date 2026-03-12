# frozen_string_literal: true

class Vk::UpdateMessageService
  include ::Vk::ParamHelpers
  pattr_initialize [:inbox!, :params!]

  def perform
    return if vk_params_message_id.blank?

    find_message
    return unless @message

    @message.update!(content: vk_params_message_content)
  rescue StandardError => e
    Rails.logger.error "[VK] UpdateMessageService error: #{e.message}"
  end

  private

  def find_message
    @message = inbox.messages.find_by(source_id: vk_params_message_id.to_s)
  end
end
