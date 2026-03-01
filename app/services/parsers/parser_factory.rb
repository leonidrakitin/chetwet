# frozen_string_literal: true

# ParserFactory — централизованный выбор парсера по source или по содержимому файла
module Parsers
  class ParserFactory
    class << self
      # Основной метод
      # @param source [String, Symbol] 'telegram', 'whatsapp', 'vk'
      # @param file_path [String, nil] опционально — для автоопределения по содержимому
      # @return [Class] класс парсера
      def for(source, file_path = nil)
        source = detect_source(source, file_path) if source.blank? || source.to_s == 'auto'

        case source.to_s.downcase.strip
        when 'telegram', 'tg' then TelegramParser
        when 'whatsapp', 'wa' then WhatsappParser
        when 'vk', 'vkontakte', 'vkcom' then VkParser
        else
          raise ArgumentError, "Неизвестный источник диалогов: #{source}. Поддерживаются: telegram, whatsapp, vk"
        end
      end

      private

      # Автоопределение по первому уровню JSON (если source не передан)
      def detect_source(_source, file_path)
        return 'telegram' if file_path.blank?
        return 'telegram' if file_path.to_s.downcase.include?('result.json') || file_path.to_s.downcase.include?('telegram')

        data = begin
          JSON.parse(File.read(file_path, encoding: 'UTF-8'), symbolize_names: false)
        rescue StandardError
          {}
        end

        if data.dig('chats', 'list').present? || data['messages'].present?
          'telegram'
        elsif data['chats'].present? || data['conversations'].present? || data.key?('fromMe') || data.key?('isFromMe')
          'whatsapp'
        elsif data['dialogs'].present? || data['peer_id'].present? || data['out'].present?
          'vk'
        else
          'telegram' # fallback
        end
      end
    end
  end
end
