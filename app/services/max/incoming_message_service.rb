# frozen_string_literal: true

class Max::IncomingMessageService
  include ::Max::ParamHelpers
  pattr_initialize [:inbox!, :params!]

  def perform
    return if max_params_from_id.blank?
    return if duplicate_message?

    set_contact
    set_conversation
    create_message
  rescue StandardError => e
    Rails.logger.error "[MAX] IncomingMessageService error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  private

  def duplicate_message?
    return false if max_params_message_id.blank?

    inbox.messages.exists?(source_id: max_params_message_id.to_s)
  end

  def set_contact
    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: max_params_from_id.to_s,
      inbox: inbox,
      contact_attributes: contact_attributes
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
  end

  def contact_attributes
    {
      name: max_params_sender_name.presence || "User #{max_params_from_id}",
      additional_attributes: {
        social_max_user_id: max_params_from_id,
        username: max_params_sender_username
      }.compact
    }
  end

  def set_conversation
    ActiveRecord::Base.transaction do
      @contact_inbox.lock!
      @conversation = if inbox.lock_to_single_conversation
                        @contact_inbox.conversations.last
                      else
                        @contact_inbox.conversations.where.not(status: :resolved).last
                      end
      @conversation ||= ::Conversation.create!(conversation_params)
    end
  end

  def conversation_params
    {
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: {
        max_user_id: max_params_from_id,
        max_chat_id: max_params_chat_id
      }
    }
  end

  def create_message
    return if bot_started? && max_params_message_content.blank?

    @message = @conversation.messages.build(
      content: max_params_message_content,
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: max_params_message_id&.to_s
    )

    process_attachments
    @message.save!
  end

  def process_attachments
    return unless message_created?

    max_params_attachments.each do |attachment|
      next unless attachment.is_a?(Hash)

      process_attachment(attachment)
    end
  end

  def process_attachment(attachment)
    type = attachment['type']
    case type
    when 'image'
      attach_image(attachment)
    when 'video'
      attach_video(attachment)
    when 'audio'
      attach_audio(attachment)
    when 'file'
      attach_file(attachment)
    when 'sticker'
      attach_sticker(attachment)
    end
  end

  def attach_image(attachment)
    url = attachment.dig('payload', 'url')
    attach_from_url(url, :image) if url
  end

  def attach_video(attachment)
    url = attachment.dig('payload', 'url')
    attach_from_url(url, :video) if url
  end

  def attach_audio(attachment)
    url = attachment.dig('payload', 'url')
    attach_from_url(url, :audio) if url
  end

  def attach_file(attachment)
    url = attachment.dig('payload', 'url')
    attach_from_url(url, :file) if url
  end

  def attach_sticker(attachment)
    url = attachment.dig('payload', 'url')
    attach_from_url(url, :image) if url
  end

  def attach_from_url(url, file_type)
    attachment_file = Down.download(url)
    @message.attachments.new(
      account_id: @message.account_id,
      file_type: file_type,
      file: {
        io: attachment_file,
        filename: attachment_file.original_filename,
        content_type: attachment_file.content_type
      }
    )
  rescue StandardError => e
    Rails.logger.warn "[MAX] Attachment download failed: #{e.message}"
  end
end
