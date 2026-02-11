class ContactSegments::MembershipRecalculationJob < ApplicationJob
  queue_as :low

  def perform
    ContactSegment.active.where(triggers_enabled: true).find_each do |segment|
      ContactSegments::MembershipEvaluationService.new(
        segment: segment,
        trigger_source: 'cron_recalc'
      ).call
    rescue StandardError => e
      Rails.logger.error("[SegmentRecalc] Error processing segment #{segment.id}: #{e.message}")
    end
  end
end
