# frozen_string_literal: true

class ConversationCleaner
  MIN_MESSAGES = 3
  MIN_AVG_MESSAGE_LENGTH = 10
  SPAM_SIMILARITY_THRESHOLD = 0.75
  MAX_MESSAGES_FROM_ONE_SENDER_PERCENT = 70

  def clean(dialogs)
    dialogs.select { |dialog| keep?(dialog) }
  end

  private

  def keep?(dialog)
    messages = dialog[:messages]
    return false if messages.size < MIN_MESSAGES

    # Только бот или системные сообщения
    senders = messages.map { |m| m[:sender_type] }.uniq
    return false if senders == ['system'] || senders == ['bot']

    # Средняя длина сообщения
    avg_length = messages.sum { |m| m[:content].to_s.strip.length } / messages.size.to_f
    return false if avg_length < MIN_AVG_MESSAGE_LENGTH

    # Рассылки / спам (один отправитель доминирует). Не применяем, если нет ни одного agent — иначе при
    # неверном agent_external_id все сообщения будут user и все диалоги отфильтруются (kept=0).
    sender_counts = messages.group_by { |m| m[:sender_type] == 'agent' ? 'agent' : 'user' }
    if sender_counts.key?('agent')
      max_percent = (sender_counts.values.max_by(&:size).size.to_f / messages.size * 100)
      return false if max_percent > MAX_MESSAGES_FROM_ONE_SENDER_PERCENT
    end

    # Быстрый minhash-like спам-фильтр (если >80% сообщений очень похожи)
    return false if spam_like?(messages)

    true
  end

  def spam_like?(messages)
    contents = messages.map { |m| m[:content].to_s.strip.downcase }
    return false if contents.size < 4

    # Простой Jaccard + длина совпадения
    first = contents[0]
    similar_count = contents.count { |c| similar?(first, c) }
    (similar_count.to_f / contents.size) > SPAM_SIMILARITY_THRESHOLD
  end

  def similar?(a, b)
    return true if a == b

    # Очень грубая, но быстрая проверка
    intersection = (a.chars & b.chars).size
    union = a.size + b.size - intersection
    intersection.to_f / union > 0.8
  end
end
