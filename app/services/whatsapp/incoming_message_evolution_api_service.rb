class Whatsapp::IncomingMessageEvolutionApiService < Whatsapp::IncomingMessageBaseService
  private

  MESSAGE_TYPE_MAP = {
    'conversation' => 'text',
    'extendedTextMessage' => 'text',
    'imageMessage' => 'image',
    'videoMessage' => 'video',
    'audioMessage' => 'audio',
    'pttMessage' => 'audio',
    'documentMessage' => 'document',
    'documentWithCaptionMessage' => 'document',
    'stickerMessage' => 'sticker',
    'locationMessage' => 'location',
    'contactMessage' => 'contacts',
    'contactsArrayMessage' => 'contacts'
  }.freeze

  def processed_params
    @processed_params ||= transform_evolution_payload
  end

  def download_attachment_file(attachment_payload)
    url = attachment_payload[:url]
    return if url.blank?

    Down.download(url)
  end

  def transform_evolution_payload
    data = params[:data]
    return {} if data.blank?
    return build_status_params(data) if params[:event] == 'messages.update'

    build_message_params(data)
  end

  def build_message_params(data)
    key = data[:key] || {}
    phone_number = extract_phone_from_jid(key[:remoteJid])
    message_type = mapped_message_type(data[:messageType])

    {
      contacts: [{ profile: { name: data[:pushName] || "+#{phone_number}" }, wa_id: phone_number }],
      messages: [{
        id: key[:id], from: phone_number, type: message_type,
        timestamp: data[:messageTimestamp],
        **extract_message_content(data[:message] || {}, message_type)
      }]
    }
  end

  def extract_phone_from_jid(jid)
    return '' if jid.blank?

    jid.split('@').first
  end

  def mapped_message_type(evolution_type)
    MESSAGE_TYPE_MAP[evolution_type] || 'text'
  end

  MEDIA_KEY_MAP = {
    'image' => :imageMessage, 'video' => :videoMessage, 'audio' => :audioMessage,
    'sticker' => :stickerMessage
  }.freeze

  CONTENT_BUILDERS = {
    'document' => :build_document_content,
    'location' => :build_location_content,
    'contacts' => :build_contacts_content
  }.freeze

  def extract_message_content(message, message_type)
    return { text: { body: extract_text(message) } } if message_type == 'text'

    builder = CONTENT_BUILDERS[message_type]
    return send(builder, message) if builder

    media_key = MEDIA_KEY_MAP[message_type]
    build_media_content(message[media_key] || message[:pttMessage] || message, message_type)
  end

  def extract_text(message)
    message[:conversation] ||
      message.dig(:extendedTextMessage, :text) ||
      message[:text] ||
      ''
  end

  def build_media_content(media_msg, type)
    {
      type.to_sym => {
        url: media_msg[:url] || media_msg[:directPath],
        mime_type: media_msg[:mimetype],
        caption: media_msg[:caption],
        id: media_msg[:url] || media_msg[:directPath]
      }
    }
  end

  def build_document_content(message)
    doc = message[:documentMessage] || message.dig(:documentWithCaptionMessage, :message, :documentMessage) || message
    {
      document: {
        url: doc[:url] || doc[:directPath],
        mime_type: doc[:mimetype],
        caption: doc[:caption],
        filename: doc[:fileName],
        id: doc[:url] || doc[:directPath]
      }
    }
  end

  def build_location_content(message)
    location = message[:locationMessage] || message
    {
      location: {
        'latitude' => location[:degreesLatitude],
        'longitude' => location[:degreesLongitude],
        'name' => location[:name],
        'address' => location[:address],
        'url' => location[:url]
      }
    }
  end

  def build_contacts_content(message)
    contact_msg = message[:contactMessage]
    return { text: { body: '' } } if contact_msg.blank?

    {
      contacts: [{
        name: { formatted_name: contact_msg[:displayName] },
        phones: [{ phone: contact_msg[:vcard]&.match(/waid=(\d+)/)&.[](1) || '' }]
      }]
    }
  end

  STATUS_MAP = {
    'DELIVERY_ACK' => 'delivered', '3' => 'delivered',
    'READ' => 'read', 'PLAYED' => 'read', '4' => 'read',
    'ERROR' => 'failed', 'FAILED' => 'failed', '5' => 'failed'
  }.freeze

  def build_status_params(data)
    key = data[:key] || data.dig(:keys, 0) || {}
    status = data[:status] || data.dig(:updates, 0, :status)
    mapped_status = STATUS_MAP[status&.to_s&.upcase] || 'sent'

    { statuses: [{ id: key[:id], status: mapped_status }] }
  end
end
