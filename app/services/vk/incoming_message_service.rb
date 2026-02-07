# frozen_string_literal: true

class Vk::IncomingMessageService
  include ::FileTypeHelper
  include ::Vk::ParamHelpers
  pattr_initialize [:inbox!, :params!]

  def perform
    return unless message_params?

    set_contact
    update_contact_avatar
    set_conversation
    @message = @conversation.messages.build(
      content: vk_params_message_content,
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      sender: @contact,
      content_attributes: vk_params_content_attributes,
      source_id: vk_params_message_id.to_s
    )

    process_message_attachments
    @message.save!
  rescue StandardError => e
    Rails.logger.error "[VK] IncomingMessageService error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  private

  def set_contact
    user_info = inbox.channel.get_vk_user_info(vk_params_from_id)
    contact_attrs = contact_attributes(user_info)

    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: vk_params_from_id.to_s,
      inbox: inbox,
      contact_attributes: contact_attrs
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
  end

  def contact_attributes(user_info)
    first_name = user_info['first_name'] || ''
    last_name = user_info['last_name'] || ''
    {
      name: "#{first_name} #{last_name}".strip.presence || "User #{vk_params_from_id}",
      additional_attributes: {
        social_vk_user_id: vk_params_from_id
      }
    }
  end

  def update_contact_avatar
    return if @contact.avatar.attached?

    avatar_url = inbox.channel.get_vk_profile_image(vk_params_from_id)
    ::Avatar::AvatarFromUrlJob.perform_later(@contact, avatar_url) if avatar_url
  end

  def conversation_params
    {
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: { peer_id: vk_params_peer_id }
    }
  end

  def set_conversation
    @conversation = if @inbox.lock_to_single_conversation
                      @contact_inbox.conversations.last
                    else
                      @contact_inbox.conversations.where.not(status: :resolved).last
                    end
    return if @conversation

    @conversation = ::Conversation.create!(conversation_params)
  end

  def process_message_attachments
    vk_params_attachments.each do |attachment|
      attach_photo(attachment) if attachment['type'] == 'photo'
      attach_doc(attachment) if attachment['type'] == 'doc'
      attach_audio(attachment) if %w[audio audio_message].include?(attachment['type'])
    end
  end

  def attach_photo(attachment)
    photo = attachment['photo'] || attachment[:photo]
    return unless photo

    sizes = photo['sizes'] || photo[:sizes] || []
    return if sizes.empty?

    url = sizes.max_by { |s| (s['width'] || s[:width] || 0).to_i }&.dig('url') ||
          sizes.max_by { |s| (s['width'] || s[:width] || 0).to_i }&.dig(:url)
    return unless url

    attach_from_url(url, :image)
  end

  def attach_doc(attachment)
    doc = attachment['doc'] || attachment[:doc]
    return unless doc

    url = doc['url'] || doc[:url]
    return unless url

    attach_from_url(url, :file)
  end

  def attach_audio(attachment)
    audio = attachment['audio'] || attachment['audio_message'] || attachment[:audio] || attachment[:audio_message]
    return unless audio

    url = audio['url'] || audio[:url]
    return unless url

    attach_from_url(url, :audio)
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
    Rails.logger.warn "VK attachment download failed: #{e.message}"
  end
end
