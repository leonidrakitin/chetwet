# frozen_string_literal: true

# VkParser — поддерживает официальный экспорт ВКонтакте и все популярные бэкапы (VK Backup, VK Teams и т.д.)
module Parsers
  class VkParser < ConversationParser
    def extract_chats(data)
      # Самые частые структуры VK JSON
      if data.is_a?(Array)
        data
      elsif data.is_a?(Hash)
        data['dialogs'] || data['chats'] || data['conversations'] ||
          data['messages']&.map { |m| { 'messages' => [m] } } || [data]
      else
        []
      end
    end

    def should_process_chat?(chat, options)
      return false if chat['type'].to_s == 'group' && !options[:include_groups]

      true
    end

    def build_dialog(chat, options)
      agent_user_id = options[:agent_user_id].to_i

      messages = process_messages(chat['messages'] || chat['items'] || [], agent_user_id, options)

      contact_name = chat['title'] || chat['name'] || 'Unknown VK User'

      {
        external_id: "vk_#{chat['id'] || chat['peer_id'] || SecureRandom.hex(8)}",
        source: 'vk',
        contact_external_id: chat['id'] || chat['peer_id']&.to_s || contact_name.parameterize,
        contact_name: contact_name,
        contact_avatar_url: chat.dig('photo', 'url') || nil,
        title: contact_name,
        messages: messages
      }
    end

    def extract_content(msg)
      text = msg['text'] || msg['body'] || ''
      if msg['attachments'].present?
        attachments = msg['attachments'].map { |a| attachment_text(a) }.join(' ')
        "#{text} #{attachments}".strip
      else
        text
      end
    end

    def attachment_text(attach)
      type = attach['type']
      case type
      when 'photo' then '[Фото]'
      when 'video' then '[Видео]'
      when 'doc' then "[Документ] #{attach.dig('doc', 'title')}"
      when 'sticker' then '[Стикер]'
      when 'audio' then '[Аудио]'
      else "[#{type}]"
      end
    end

    def determine_sender_type(msg, agent_user_id)
      # VK: out = 1 — исходящее (агент), out = 0 — входящее (клиент)
      # Или from_id == agent_user_id
      out = msg['out'] || msg['is_out'] || false
      from_id = msg['from_id']&.to_i || 0

      out == 1 || out.to_s == 'true' || from_id == agent_user_id ? 'agent' : 'user'
    end

    def message_valid?(msg)
      return false if msg.nil?
      return false if msg['action'].present? # системные действия (пользователь вышел и т.д.)

      true
    end

    def parse_timestamp(msg)
      ts = msg['date'] || msg['timestamp'] || msg['time']
      ts.is_a?(Integer) ? Time.zone.at(ts) : super
    end
  end
end
