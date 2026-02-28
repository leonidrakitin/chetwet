# frozen_string_literal: true

# ConversationParser — абстрактный базовый класс для всех источников
# Использует Template Method pattern + общую логику статистики и загрузки JSON
class ConversationParser
  attr_reader :stats

  def initialize
    @stats = {
      total_chats: 0,
      processed_chats: 0,
      skipped_chats: 0,
      total_messages: 0,
      skipped_messages: 0
    }
  end

  # Главный публичный метод
  def parse(file_path, options = {})
    data = load_json(file_path)
    return [] unless data

    chats = extract_chats(data)
    @stats[:total_chats] = chats.size

    unified_dialogs = []

    chats.each do |chat|
      next unless should_process_chat?(chat, options)

      dialog = build_dialog(chat, options)
      next if dialog[:messages].empty?

      unified_dialogs << dialog
      @stats[:processed_chats] += 1
      @stats[:total_messages] += dialog[:messages].size
    end

    @stats[:skipped_chats] = @stats[:total_chats] - @stats[:processed_chats]
    unified_dialogs
  end

  private

  def load_json(file_path)
    JSON.parse(File.read(file_path, encoding: 'UTF-8'), symbolize_names: false)
  rescue JSON::ParserError, Errno::ENOENT => e
    Rails.logger.error "[#{self.class.name}] Не удалось загрузить JSON: #{e.message}"
    nil
  end

  # === Методы, которые ОБЯЗАТЕЛЬНО переопределяют наследники ===
  def extract_chats(_data)
    raise NotImplementedError, 'Наследник должен реализовать #extract_chats'
  end

  def should_process_chat?(_chat, _options)
    true # по умолчанию всё обрабатываем
  end

  def build_dialog(_chat, _options)
    raise NotImplementedError, 'Наследник должен реализовать #build_dialog'
  end

  # === Вспомогательные методы (можно переопределять) ===
  def process_messages(raw_messages, agent_identifier, options = {})
    messages = []
    raw_messages.each do |msg|
      next unless message_valid?(msg)

      content = extract_content(msg)
      next if content.blank?

      sender_type = determine_sender_type(msg, agent_identifier)

      messages << {
        external_id: msg['id']&.to_s || SecureRandom.hex(8),
        created_at: parse_timestamp(msg),
        sender_type: sender_type,
        content: content.to_s.strip,
        content_type: content.to_s.strip.start_with?('[') ? 'system' : 'text'
      }
    end

    messages = messages.first(options[:max_messages]) if options[:max_messages]
    messages
  end

  def message_valid?(_msg)
    true # переопределяется в наследниках при необходимости
  end

  def extract_content(msg)
    # Базовая реализация — можно расширять
    msg['text'] || msg['body'] || msg['message'] || ''
  end

  def determine_sender_type(_msg, _agent_identifier)
    'user' # переопределяется
  end

  def parse_timestamp(msg)
    ts = msg['timestamp'] || msg['date'] || msg['time'] || msg['t']
    case ts
    when Integer, Float then Time.zone.at(ts)
    when String then Time.zone.parse(ts)
    else Time.zone.now
    end
  rescue ArgumentError
    Time.zone.now
  end
end
