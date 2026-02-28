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

    [
      "Migration ##{@migration.id} | source=#{@migration.source}",
      "total=#{preprocess[:processed] || 0}",
      "kept=#{preprocess[:ready_for_import] || 0}",
      "imported=#{import[:imported] || 0}",
      "faqs=#{r[:total_faqs_generated] || 0}"
    ].join(' | ')
  end
end
