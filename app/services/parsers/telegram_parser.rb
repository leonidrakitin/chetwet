# frozen_string_literal: true

module Parsers
  class TelegramParser < ConversationParser
    def extract_chats(data)
      # Полный экспорт Telegram Desktop
      if data.dig('chats', 'list').present?
        data.dig('chats', 'list').select { |c| c['messages'].present? }
      # Экспорт одного чата
      elsif data['messages'].present?
        [data]
      else
        []
      end
    end

    def should_process_chat?(chat, options)
      chat_type = chat['type'].to_s.downcase

      # Пропускаем каналы и группы по умолчанию
      return false if chat_type.include?('channel')
      return false if chat_type.include?('group') && !options[:include_groups]

      # Фильтры
      return chat['id'].to_s == options[:chat_id].to_s if options[:chat_id].present?

      return false if options[:chat_title].present? && !chat['name']&.downcase&.include?(options[:chat_title].to_s.downcase)

      true
    end

    def build_dialog(chat, options)
      agent_user_id = options[:agent_user_id].to_i

      messages = process_messages(chat['messages'] || [], agent_user_id, options)

      {
        external_id: "tg_#{chat['id']}",
        source: 'telegram',
        contact_external_id: chat['id'].to_s,
        contact_name: chat['name'] || 'Unknown Telegram User',
        contact_avatar_url: chat.dig('photo', 'file'),
        title: chat['name'],
        messages: messages
      }
    end

    def extract_content(msg)
      return '' unless msg['type'] == 'message'

      # Текст (строка или массив)
      if msg['text'].present?
        if msg['text'].is_a?(Array)
          msg['text'].map { |part| part.is_a?(Hash) ? part['text'] : part.to_s }.join(' ')
        else
          msg['text'].to_s
        end

      # Медиа с подписью
      elsif msg['photo'].present? && msg['caption'].present?
        "[Фото] #{msg['caption']}"
      elsif msg['file'].present? && msg['caption'].present?
        "[Файл] #{msg['caption']}"
      elsif msg['sticker'].present?
        '[Стикер]'
      elsif msg['voice_message'].present?
        '[Голосовое сообщение]'
      elsif msg['video'].present? || msg['video_message'].present?
        '[Видео]'
      elsif msg['document'].present?
        "[Документ] #{msg['file_name'] || ''}"
      else
        ''
      end
    end

    def determine_sender_type(msg, agent_user_id)
      return 'system' if msg['from_id'].to_s.start_with?('channel')

      from_id = extract_user_id(msg['from_id'])
      from_id == agent_user_id ? 'agent' : 'user'
    end

    def message_valid?(msg)
      msg['type'] == 'message' && extract_content(msg).present?
    end

    private

    def extract_user_id(from_id)
      from_id.to_s.gsub(/^(user|channel)/, '').to_i
    end
  end
end
