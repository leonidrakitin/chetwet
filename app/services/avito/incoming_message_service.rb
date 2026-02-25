# frozen_string_literal: true

class Avito::IncomingMessageService
  include ::FileTypeHelper
  include ::Avito::ParamHelpers

  pattr_initialize [:inbox!, :params!]

  def perform
    return unless message_params?
    return unless incoming_message?
    return if duplicate_message?

    set_contact
    set_conversation
    create_message
    mark_chat_as_read
  rescue StandardError => e
    Rails.logger.error "[Avito] IncomingMessageService error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  private

  def set_contact
    user_info = fetch_contact_info
    name = extract_contact_name(user_info)

    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: avito_author_id.to_s,
      inbox: inbox,
      contact_attributes: {
        name: name,
        additional_attributes: {
          avito_user_id: avito_author_id
        }
      }
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
    update_contact_avatar(user_info)
  end

  def fetch_contact_info
    inbox.channel.get_chat_user_info(avito_chat_id)
  rescue StandardError => e
    Rails.logger.warn "[Avito] Could not fetch contact info: #{e.message}"
    {}
  end

  def extract_contact_name(user_info)
    return "Пользователь #{avito_author_id}" if user_info.blank?

    name = user_info['name'] || user_info[:name]
    name.presence || "Пользователь #{avito_author_id}"
  end

  def update_contact_avatar(user_info)
    return if @contact.avatar.attached?

    avatar_url = user_info['avatar'] || user_info['photo'] || user_info[:avatar]
    return unless avatar_url.present?

    ::Avatar::AvatarFromUrlJob.perform_later(@contact, avatar_url)
  end

  def set_conversation
    @conversation = if inbox.lock_to_single_conversation
                      @contact_inbox.conversations.last
                    else
                      @contact_inbox.conversations.where.not(status: :resolved).last
                    end

    if @conversation.nil?
      last_resolved = @contact_inbox.conversations.where(status: :resolved).order(updated_at: :desc).first
      if last_resolved
        last_resolved.open!
        @conversation = last_resolved
        # Update chat_id in case it changed
        @conversation.update!(additional_attributes: @conversation.additional_attributes.merge('chat_id' => avito_chat_id))
        return
      end
    end

    @conversation ||= ::Conversation.create!(conversation_params)
  end

  def conversation_params
    {
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: { 'chat_id' => avito_chat_id }
    }
  end

  def create_message
    @message = @conversation.messages.build(
      content: message_content_text,
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: :incoming,
      sender: @contact,
      content_attributes: content_attributes,
      source_id: avito_message_id.to_s
    )

    process_attachments
    @message.save!
  end

  def message_content_text
    case avito_message_type
    when 'text'
      avito_message_text
    when 'link'
      avito_link_url.presence || avito_message_text
    else
      avito_message_text.presence
    end
  end

  def content_attributes
    attrs = {}
    # Check for reply
    attrs['in_reply_to_external_id'] = avito_message.dig(:quote, :id) if avito_message[:quote].present?
    attrs
  end

  def process_attachments
    case avito_message_type
    when 'image'
      attach_image
    when 'voice'
      attach_voice
    when 'link'
      # Link is already set as content text, nothing extra needed
    end
  end

  def attach_image
    image = avito_image_content
    return unless image

    # Avito image content contains URLs in different sizes
    url = image['url'] || image[:url] ||
          image['1280x960'] || image['640x480'] || image['460x345'] ||
          image.values.find { |v| v.is_a?(String) && v.start_with?('http') }

    return unless url

    attach_from_url(url, :image)
  end

  def attach_voice
    voice_id = avito_voice_id
    return unless voice_id.present?

    url = inbox.channel.get_voice_file_url(voice_id)
    return unless url

    attach_from_url(url, :audio)
  rescue StandardError => e
    Rails.logger.warn "[Avito] attach_voice failed: #{e.message}"
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
    Rails.logger.warn "[Avito] attach_from_url failed for #{url}: #{e.message}"
  end

  def mark_chat_as_read
    inbox.channel.mark_chat_as_read(avito_chat_id)
  rescue StandardError => e
    Rails.logger.warn "[Avito] mark_chat_as_read failed: #{e.message}"
  end
end
