# frozen_string_literal: true

class BulkMigrationReportService
  def initialize(migration)
    @migration = migration
  end

  def deliver!
    Rails.logger.info "[BulkMigrationReport] #{summary}"
  end

  private

  def summary
    r = @migration.report.with_indifferent_access
    preprocess = r[:preprocess_stats] || {}
    import = r[:import_stats] || {}
    total = (preprocess[:processed] || 0).to_i
    kept = (preprocess[:ready_for_import] || 0).to_i

    line = [
      "Migration ##{@migration.id} | source=#{@migration.source}",
      "total=#{total}",
      "kept=#{kept}",
      "imported=#{import[:imported] || 0}",
      "faqs=#{r[:total_faqs_generated] || 0}"
    ].join(' | ')
    if total.positive? && kept.zero?
      line += " | Hint: set agent_external_id to the agent's Telegram numeric ID from the export so messages are split into agent/user"
    end
    line
  end
end
