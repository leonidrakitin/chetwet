# frozen_string_literal: true

# ConversationPreprocessorService
# Главный сервис предобработки диалогов перед импортом.
# Делает две вещи:
#   1. Очистка (мусор, рассылки, короткие диалоги)
#   2. Дедупликация на уровне эмбеддингов (чтобы не тратить LLM на одинаковые диалоги)
class ConversationPreprocessorService
  CLEANER_THRESHOLD = 0.22   # cosine similarity threshold для дедуп диалогов
  BATCH_SIZE = 50            # сколько диалогов одновременно отправляем на эмбеддинг

  attr_reader :account, :stats

  def initialize(account)
    @account = account
    @stats = {
      total: 0,
      cleaned: 0,
      deduplicated: 0,
      kept: 0
    }
  end

  # Основной метод
  # @param dialogs [Array<Hash>] массив унифицированных диалогов из парсера
  # @return [Array<Hash>] только чистые и уникальные диалоги
  def preprocess(dialogs)
    @stats[:total] = dialogs.size
    return [] if dialogs.empty?

    # Шаг 1: Очистка
    cleaned = ConversationCleaner.new.clean(dialogs)
    @stats[:cleaned] = dialogs.size - cleaned.size

    # Шаг 2: Дедупликация
    unique = ConversationDeduplicator.new(account).deduplicate(cleaned)
    @stats[:deduplicated] = cleaned.size - unique.size
    @stats[:kept] = unique.size

    unique
  end

  def report
    {
      processed: stats[:total],
      skipped_as_spam_or_short: stats[:cleaned],
      duplicates_removed: stats[:deduplicated],
      ready_for_import: stats[:kept]
    }
  end
end
