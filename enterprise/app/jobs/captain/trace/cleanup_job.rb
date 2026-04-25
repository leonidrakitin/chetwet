class Captain::Trace::CleanupJob < ApplicationJob
  queue_as :purgable

  DEFAULT_TTL_DAYS = 30
  BATCH_SIZE = 1_000
  MAX_BATCHES_PER_RUN = 50

  def perform
    ttl_days = configured_ttl_days
    return if ttl_days <= 0

    cutoff = ttl_days.days.ago
    deleted = delete_in_batches(cutoff)
    Rails.logger.info("[Captain::Trace::CleanupJob] removed=#{deleted} cutoff=#{cutoff.iso8601} ttl_days=#{ttl_days}")
  end

  private

  def configured_ttl_days
    raw = GlobalConfigService.load('CAPTAIN_TRACE_TTL_DAYS', DEFAULT_TTL_DAYS).to_i
    raw.zero? ? DEFAULT_TTL_DAYS : raw
  end

  def delete_in_batches(cutoff)
    deleted = 0
    MAX_BATCHES_PER_RUN.times do
      ids = Captain::TraceEvent.where('created_at < ?', cutoff).limit(BATCH_SIZE).pluck(:id)
      break if ids.empty?

      deleted += Captain::TraceEvent.where(id: ids).delete_all
    end
    deleted
  end
end
