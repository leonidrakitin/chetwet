# frozen_string_literal: true

# Syncs messages sent from VK admin interface (message_reply with out=1) into Chatwoot
# so both Chatwoot agents and VK admins see the full conversation history.
class Vk::OutgoingMessageSyncService
  include ::Vk::ParamHelpers
  pattr_initialize [:inbox!, :params!]

  def perform
    return unless message_params?
    return if duplicate_message?

    return if vk_params_random_id.present? && update_message_by_random_id

    set_contact
    set_conversation
    return unless @conversation

    return if update_pending_chatwoot_message
    return if update_recent_chatwoot_message_fallback

    create_outgoing_message
  rescue StandardError => e
    Rails.logger.error "[VK] OutgoingMessageSyncService error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  private

  def duplicate_message?
    exists = inbox.messages.exists?(source_id: vk_params_message_id.to_s)
    Rails.logger.info "[VK] Skip outgoing sync: source_id=#{vk_params_message_id} already exists" if exists
    exists
  end

  def update_message_by_random_id
    pending = find_message_by_random_id
    return false unless pending

    pending.update!(source_id: vk_params_message_id.to_s)
    Rails.logger.info "[VK] Updated message #{pending.id} with source_id via random_id deduplication"
    true
  end

  def find_message_by_random_id
    inbox.messages.outgoing
         .where("external_source_ids->>'vk_random_id' = ?", vk_params_random_id.to_s)
         .first
  end

  def update_pending_chatwoot_message
    pending = find_pending_chatwoot_message
    return false unless pending

    update_message_source_from_vk!(pending)
    Rails.logger.info "[VK] Updated message #{pending.id} via pending message deduplication"
    true
  end

  def find_pending_chatwoot_message
    return unless @conversation

    @conversation.messages.outgoing
                 .where(source_id: [nil, ''])
                 .where(content: vk_params_message_content)
                 .where('created_at > ?', 2.minutes.ago)
                 .order(created_at: :desc)
                 .first
  end

  def update_recent_chatwoot_message_fallback
    pending = find_recent_inbox_message_without_source
    return false unless pending

    update_message_source_from_vk!(pending)
    Rails.logger.info "[VK] Updated message #{pending.id} via inbox-level fallback deduplication"
    true
  end

  def find_recent_inbox_message_without_source
    inbox.messages.outgoing
         .where(source_id: [nil, ''])
         .where(content: vk_params_message_content)
         .where(sender_type: %w[User Captain::Assistant])
         .where('created_at > ?', 2.minutes.ago)
         .order(created_at: :desc)
         .first
  end

  def update_message_source_from_vk!(message)
    attrs = { source_id: vk_params_message_id.to_s }
    if vk_params_random_id.present?
      attrs[:external_source_ids] = (message.external_source_ids || {}).merge('vk_random_id' => vk_params_random_id.to_s)
    end
    message.update!(attrs)
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
  end

  def process_message_attachments
    vk_params_attachments.each do |attachment|
      next unless attachment.is_a?(Hash)

      attach_photo(attachment) if attachment['type'] == 'photo'
      attach_doc(attachment) if attachment['type'] == 'doc'
      attach_audio(attachment) if %w[audio audio_message].include?(attachment['type'])
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
