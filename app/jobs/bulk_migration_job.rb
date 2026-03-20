# frozen_string_literal: true

# BulkMigrationJob
# Главный Sidekiq-воркер миграции исторических диалогов.
# Использует парсеры, ConversationPreprocessorService и ConversationImporterService.
class BulkMigrationJob < ApplicationJob
  queue_as :captain_migration

  sidekiq_options retry: 2, dead: true

  BATCH_SIZE = 25
  PROGRESS_KEY_TTL = 24.hours

  def perform(bulk_migration_id, options = {})
    migration = BulkMigration.find(bulk_migration_id)
    return if migration.status == 'completed'

    if migration.source.in?(%w[telegram_personal vk_personal])
      max_concurrent = InstallationConfig.find_by(name: 'LIVE_MIGRATION_MAX_CONCURRENCY')&.value.to_i
      max_concurrent = 5 if max_concurrent.zero?
      running = BulkMigration.where(source: migration.source, status: 'processing').count
      if running >= max_concurrent
        self.class.set(wait: 30.seconds).perform_later(bulk_migration_id, options)
        return
      end
    end

    migration.update!(status: 'processing', started_at: Time.current)
    run_migration(migration, options)
  rescue StandardError => e
    migration&.update!(status: 'failed', finished_at: Time.current,
                       report: { error: e.message, backtrace: e.backtrace.first(10) })
    Rails.logger.error "[BulkMigrationJob] Ошибка миграции ##{migration&.id}: #{e.message}"
    raise
  end

  private

  def run_migration(migration, options)
    opts = (options || {}).with_indifferent_access
    dry_run = opts[:dry_run] == true || migration.dry_run
    Rails.logger.info "[BulkMigrationJob] Запуск ##{migration.id} | dry_run=#{dry_run} | source=#{migration.source}"

    if migration.source.in?(%w[telegram_personal vk_personal])
      source_stats, parsed_dialogs = fetch_live_dialogs(migration)
    else
      parser, parsed_dialogs = parse_file(migration)
      source_stats = parser.stats
    end

    preprocessor, dialogs = preprocess_dialogs(migration, parsed_dialogs)
    import_results = import_dialogs(dialogs, migration, dry_run)

    report = build_final_report(migration, source_stats, preprocessor, import_results, dry_run)
    migration.update!(status: 'completed', finished_at: Time.current, report: report)
    BulkMigrationReportService.new(migration).deliver!
    Rails.logger.info "[BulkMigrationJob] Завершена ##{migration.id}. #{report[:summary]}"
  end

  def parse_file(migration)
    parser = parser_for(migration.source).new
    parsed = []
    migration.file.blob.open { |tmpfile| parsed = parser.parse(tmpfile.path, parser_options(migration)) }
    [parser, parsed]
  end

  def preprocess_dialogs(migration, parsed_dialogs)
    preprocessor = ConversationPreprocessorService.new(
      migration.account,
      dialog_dedup_threshold: migration.dialog_dedup_threshold,
      session_gap_minutes: migration.session_gap_minutes
    )
    dialogs = preprocessor.preprocess(parsed_dialogs)
    migration.update!(total_dialogs: dialogs.size, processed: 0)
    [preprocessor, dialogs]
  end

  def import_dialogs(dialogs, migration, dry_run)
    return { imported: 0, skipped: dialogs.size, faqs_generated: 0 } if dry_run

    process_batch_import(dialogs, migration.inbox, migration)
  end

  def parser_for(source)
    case source.to_s.downcase
    when 'telegram' then Parsers::TelegramParser
    when 'whatsapp' then Parsers::WhatsappParser
    when 'vk', 'vkontakte' then Parsers::VkParser
    else raise ArgumentError, "Неизвестный source: #{source}"
    end
  end

  def parser_options(migration)
    {
      agent_user_id: migration.agent_external_id,
      agent_phone: migration.agent_external_id,
      include_groups: migration.include_groups || false,
      max_messages: migration.max_messages_per_dialog
    }.compact
  end

  def fetch_live_dialogs(migration)
    case migration.source
    when 'telegram_personal' then fetch_telegram_live_dialogs(migration)
    when 'vk_personal' then fetch_vk_live_dialogs(migration)
    end
  end

  def fetch_telegram_live_dialogs(migration)
    fetcher = TelegramLiveFetcherService.new(
      migration.telegram_session,
      max_chats: migration.config&.dig('max_chats'),
      max_messages_per_chat: migration.config&.dig('max_messages_per_chat') || migration.max_messages_per_dialog,
      include_groups: migration.include_groups,
      date_limit_months: migration.date_limit_months
    )
    dialogs = fetcher.fetch do |current, total|
      if (current % 10).zero?
        migration.update!(total_dialogs: total, processed: current)
        broadcast_progress(migration)
      end
    end
    [fetcher.stats, dialogs]
  end

  def fetch_vk_live_dialogs(migration)
    fetcher = VkLiveFetcherService.new(
      migration.config['vk_access_token'],
      max_chats: migration.config&.dig('max_chats'),
      max_messages_per_chat: migration.config&.dig('max_messages_per_chat') || migration.max_messages_per_dialog,
      include_groups: migration.include_groups,
      date_limit_months: migration.date_limit_months
    )
    dialogs = fetcher.fetch do |current, total|
      if (current % 10).zero?
        migration.update!(total_dialogs: total, processed: current)
        broadcast_progress(migration)
      end
    end
    [fetcher.stats, dialogs]
  end

  def process_batch_import(dialogs, inbox, migration)
    imported = 0
    faqs_generated = 0
    processed_count = 0

    dialogs.each_slice(BATCH_SIZE) do |batch|
      batch.each do |dialog|
        result = ConversationImporterService.new(inbox, migration.captain_assistant).import!(dialog)
        imported += 1 if result[:success]
        faqs_generated += result[:faqs_generated] || 0
      end

      processed_count += batch.size
      migration.update!(processed: processed_count)
      broadcast_progress(migration)
    end

    { imported: imported, skipped: dialogs.size - imported, faqs_generated: faqs_generated }
  end

  def build_final_report(migration, source_stats, preprocessor, import_results, dry_run)
    {
      summary: dry_run ? "DRY-RUN: готово к импорту #{migration.processed} диалогов" : "#{import_results[:imported]} диалогов импортировано",
      source_stats: source_stats,
      preprocess_stats: preprocessor.report,
      import_stats: import_results,
      total_faqs_generated: import_results[:faqs_generated],
      dry_run: dry_run,
      finished_at: Time.current.iso8601
    }
  end

  def broadcast_progress(migration)
    return if migration.total_dialogs.to_i.zero?

    ActionCable.server.broadcast(
      "bulk_migration_#{migration.id}",
      {
        progress: migration.processed.to_f / migration.total_dialogs * 100,
        processed: migration.processed,
        total: migration.total_dialogs,
        status: migration.status
      }
    )
  end
end
