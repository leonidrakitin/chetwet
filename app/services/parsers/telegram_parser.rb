# frozen_string_literal: true

class Parsers::TelegramParser < Parsers::ConversationParser
  MEDIA_LABELS = {
    'sticker' => '[Стикер]',
    'voice_message' => '[Голосовое сообщение]',
    'video' => '[Видео]',
    'video_message' => '[Видео]'
  }.freeze

  def extract_chats(data)
    chats = data.dig('chats', 'list')
    return chats.select { |c| c['messages'].present? } if chats

    data['messages'].present? ? [data] : []
  end

  def should_process_chat?(chat, options)
    chat_type = chat['type'].to_s.downcase
    return false if blocked_chat_type?(chat_type, options)

    matches_chat_filter?(chat, options)
  end

  def build_dialog(chat, options)
    id   = chat['id']
    name = chat['name']

    {
      external_id: "tg_#{id}",
      source: 'telegram',
      contact_external_id: id.to_s,
      contact_name: name || 'Unknown Telegram User',
      contact_avatar_url: chat.dig('photo', 'file'),
      title: name,
      messages: process_messages(chat['messages'] || [], options[:agent_user_id].to_i, options)
    }
  end

  def extract_content(msg)
    return '' unless msg['type'] == 'message'

    text_content(msg) || captioned_media_content(msg) || labeled_media_content(msg) || ''
  end

  def determine_sender_type(msg, agent_user_id)
    return 'system' if msg['from_id'].to_s.start_with?('channel')
    return 'user'   if agent_user_id.to_i.zero?

    extract_user_id(msg['from_id']) == agent_user_id.to_i ? 'agent' : 'user'
  end

  def message_valid?(msg)
    msg['type'] == 'message' && extract_content(msg).present?
  end

  private

  def blocked_chat_type?(chat_type, options)
    chat_type.include?('channel') || (chat_type.include?('group') && !options[:include_groups])
  end

  def matches_chat_filter?(chat, options)
    return chat['id'].to_s == options[:chat_id].to_s if options[:chat_id].present?
    return false if options[:chat_title].present? &&
                    !chat['name']&.downcase&.include?(options[:chat_title].to_s.downcase)

    true
  end

  def text_content(msg)
    flatten_text(msg['text']) if msg['text'].present?
  end

  def captioned_media_content(msg)
    if msg['photo'].present? && msg['caption'].present?
      "[Фото] #{msg['caption']}"
    elsif msg['file'].present? && msg['caption'].present?
      "[Файл] #{msg['caption']}"
    end
  end

  def labeled_media_content(msg)
    label = MEDIA_LABELS.find { |k, _| msg[k].present? }&.last
    label || ("[Документ] #{msg['file_name'] || ''}" if msg['document'].present?)
  end

  def flatten_text(text)
    return text.map { |part| part.is_a?(Hash) ? part['text'] : part.to_s }.join if text.is_a?(Array)

    text.to_s
  end

  def extract_user_id(from_id)
    return (from_id['user_id'] || from_id[:user_id]).to_i if from_id.is_a?(Hash)

    from_id.to_s.gsub(/^(user|channel|chat)/, '').to_i
  end
end
