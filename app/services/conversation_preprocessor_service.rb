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

  def initialize(account, dialog_dedup_threshold: nil, session_gap_minutes: nil)
    @account = account
    @dialog_dedup_threshold = dialog_dedup_threshold
    @session_gap_minutes = session_gap_minutes
    @stats = {
      total: 0,
      cleaned: 0,
      deduplicated: 0,
      sessions_created: 0,
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
    dedup_opts = @dialog_dedup_threshold ? { threshold: @dialog_dedup_threshold } : {}
    unique = ConversationDeduplicator.new(account, **dedup_opts).deduplicate(cleaned)
    @stats[:deduplicated] = cleaned.size - unique.size

    # Шаг 3: Сегментация по сессиям (если задан gap)
    result = if @session_gap_minutes
               segmented = ConversationSessionSegmenter.new(gap_minutes: @session_gap_minutes).segment(unique)
               @stats[:sessions_created] = segmented.size - unique.size
               segmented
             else
               unique
             end

    @stats[:kept] = result.size
    result
  end

  def report
    {
      processed: stats[:total],
      skipped_as_spam_or_short: stats[:cleaned],
      duplicates_removed: stats[:deduplicated],
      sessions_created: stats[:sessions_created],
      ready_for_import: stats[:kept]
    }
  end
end
