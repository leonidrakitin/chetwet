# frozen_string_literal: true

class Vk::MessagePermissionService
  pattr_initialize [:inbox!, :params!, :action!]

  def perform
    return if user_id.blank?

    find_contact_and_conversation
    return unless @conversation

    create_activity_message
    @conversation.resolved! if action == :deny
  rescue StandardError => e
    Rails.logger.error "[VK] MessagePermissionService error: #{e.message}"
  end

  private

  def user_id
    params[:user_id]
  end

  def find_contact_and_conversation
    contact_inbox = inbox.contact_inboxes.find_by(source_id: user_id.to_s)
    return unless contact_inbox

    @contact = contact_inbox.contact
    @conversation = contact_inbox.conversations.where.not(status: :resolved).last
  end

  def create_activity_message
    content = I18n.t("conversations.activity.vk.message_#{action}")
    @conversation.messages.create!(
      account_id: @conversation.account_id,
      inbox_id: inbox.id,
      message_type: :activity,
      content: content
    )
  end
end
