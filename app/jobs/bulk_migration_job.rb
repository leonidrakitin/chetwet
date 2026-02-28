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

    parser, parsed_dialogs = parse_file(migration)
    preprocessor, dialogs = preprocess_dialogs(migration, parsed_dialogs)
    import_results = import_dialogs(dialogs, migration, dry_run)

    report = build_final_report(migration, parser, preprocessor, import_results, dry_run)
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
    preprocessor = ConversationPreprocessorService.new(migration.account)
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
    when 'telegram' then TelegramParser
    when 'whatsapp' then WhatsAppParser
    when 'vk', 'vkontakte' then VkParser
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

  def build_final_report(migration, parser, preprocessor, import_results, dry_run)
    {
      summary: dry_run ? "DRY-RUN: готово к импорту #{migration.processed} диалогов" : "#{import_results[:imported]} диалогов импортировано",
      parser_stats: parser.stats,
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
