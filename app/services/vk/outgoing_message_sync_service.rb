# frozen_string_literal: true

# Syncs messages sent from VK admin interface (message_reply with out=1) into Chatwoot
# so both Chatwoot agents and VK admins see the full conversation history.
class Vk::OutgoingMessageSyncService
  include ::Vk::ParamHelpers
  pattr_initialize [:inbox!, :params!]

  AUDIO_ATTACHMENT_TYPES = %w[audio audio_message].freeze

  def perform
    return unless message_params?
    return if deduplicate_outgoing_echo

    set_contact
    set_conversation
    return unless @conversation

    create_outgoing_message
  rescue StandardError => e
    Rails.logger.error "[VK] OutgoingMessageSyncService error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  private

  def deduplicate_outgoing_echo
    Vk::OutgoingMessageDeduplicator.new(
      inbox: inbox,
      vk_message_id: vk_params_message_id,
      vk_random_id: vk_params_random_id
    ).perform
  end

  def set_contact
    peer_id = vk_params_peer_id
    return unless peer_id

    user_info = inbox.channel.get_vk_user_info(peer_id)
    contact_attrs = contact_attributes(user_info)

    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: peer_id.to_s,
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
      name: "#{first_name} #{last_name}".strip.presence || "User #{vk_params_peer_id}",
      additional_attributes: {}
    }
  end

  def set_conversation
    return unless @contact_inbox

    @conversation = if inbox.lock_to_single_conversation
                      @contact_inbox.conversations.last
                    else
                      @contact_inbox.conversations.where.not(status: :resolved).last
                    end

    return if @conversation

    @conversation = ::Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: { peer_id: vk_params_peer_id }
    )
  end

  def create_outgoing_message
    @message = @conversation.messages.build(
      content: vk_params_message_content,
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: :outgoing,
      status: :delivered,
      sender: nil,
      source_id: vk_params_message_id.to_s,
      # Like Telegram::IncomingMessageService (business outgoing): no external_echo.
      # Otherwise human_response? treats the sync as a human reply and opens Captain + auto-assign.
      content_attributes: vk_params_content_attributes
    )

    process_message_attachments
    @message.save!
  rescue ActiveRecord::RecordNotUnique
    # Race with SendOnVkService echo: outgoing message with this source_id was just persisted.
    Rails.logger.info "[VK] Skip outgoing sync on unique violation: source_id=#{vk_params_message_id}"
  end

  def process_message_attachments
    vk_params_attachments.each do |attachment|
      next unless attachment.is_a?(Hash)

      attach_photo(attachment) if attachment['type'] == 'photo'
      attach_doc(attachment) if attachment['type'] == 'doc'
      attach_audio(attachment) if AUDIO_ATTACHMENT_TYPES.include?(attachment['type'])
      attach_market(attachment) if attachment['type'] == 'market'
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

    url = audio['url'] || audio[:url] || audio['link_mp3'] || audio[:link_mp3] || audio['link_ogg'] || audio[:link_ogg]
    return unless url

    attach_from_url(url, :audio)
  end

  def attach_market(attachment)
    market = attachment['market'] || attachment[:market]
    return unless market

    price_text = market.dig('price', 'text')
    price_text = CGI.unescape_html(price_text.to_s) if price_text

    @message.attachments.new(
      account_id: @message.account_id,
      file_type: :market,
      external_url: market['market_url'] || market[:market_url],
      fallback_title: market['title'] || market[:title],
      meta: {
        title: market['title'] || market[:title],
        description: market['description'] || market[:description],
        price_text: price_text,
        thumb_photo: market['thumb_photo'] || market[:thumb_photo],
        category_name: market.dig('category', 'name'),
        market_url: market['market_url'] || market[:market_url]
      }.compact
    )
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
