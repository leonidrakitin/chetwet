# frozen_string_literal: true

class WhatsAppParser < ConversationParser
  def extract_chats(data)
    if data.is_a?(Array)
      data
    elsif data.is_a?(Hash)
      data['chats'] || data['conversations'] || data['chat'] || [data]
    else
      []
    end
  end

  def build_dialog(chat, options)
    agent_phone = options[:agent_phone].to_s.strip
    messages = process_messages(chat['messages'] || chat['msgs'] || [], agent_phone, options)

    contact_name = chat_name(chat)

    {
      external_id: "wa_#{chat['id'] || chat['chatId'] || SecureRandom.hex(8)}",
      source: 'whatsapp',
      contact_external_id: chat['id'] || chat['chatId'] || contact_name.parameterize,
      contact_name: contact_name,
      contact_avatar_url: nil,
      title: contact_name,
      messages: messages
    }
  end

  def chat_name(chat)
    chat['name'] || chat['title'] || chat['contact'] || chat['chatName'] || 'Unknown WhatsApp User'
  end

  def extract_content(msg)
    body = msg['body'] || msg['text'] || msg['message'] || ''
    case msg['type']&.downcase
    when 'image', 'photo' then "[Фото] #{body}"
    when 'video' then "[Видео] #{body}"
    when 'document', 'file' then "[Документ] #{msg['fileName'] || ''} #{body}"
    when 'audio', 'voice' then '[Голосовое сообщение]'
    when 'sticker' then '[Стикер]'
    when 'location' then '[Местоположение]'
    else body.to_s
    end
  end

  def determine_sender_type(msg, agent_phone)
    from_me = msg['fromMe'] || msg['isFromMe'] || msg['from_me'] || msg['owner'] || false
    from = msg['from'] || msg['author'] || msg['sender'] || ''

    from_me == true || from_me.to_s == 'true' || (agent_phone.present? && from.to_s.include?(agent_phone)) ? 'agent' : 'user'
  end

  def message_valid?(msg)
    return false if msg.nil?
    return false if msg['type'].to_s.in?(%w[notification system deleted])

    !(msg['body'].to_s.strip.empty? && msg['type'].to_s != 'chat')
  end
end
