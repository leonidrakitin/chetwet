class Captain::InsightsService
  ROUTING_LABELS = %w[direct faq scenario_handoff human].freeze
  CONFIDENCE_BUCKETS = {
    'low' => (0.0..0.4),
    'medium' => (0.4..0.6),
    'high' => (0.6..0.8),
    'very_high' => (0.8..1.01)
  }.freeze
  APPROVAL_STATUSES = %w[pending resolved expired].freeze

  def initialize(account:, since:, until_at:, assistant_id: nil)
    @account = account
    @since = since
    @until_at = until_at
    @assistant_id = assistant_id
  end

  def call
    runtime_rows = runtime_snapshots
    {
      period: { from: @since.iso8601, to: @until_at.iso8601, days: ((@until_at - @since) / 1.day).round },
      assistant_id: @assistant_id&.to_i,
      conversations_with_captain: runtime_rows.size,
      routing: routing_breakdown(runtime_rows),
      confidence_buckets: confidence_buckets(runtime_rows),
      approvals: approvals_breakdown,
      escalations: escalations_stats(runtime_rows),
      top_assistants: top_assistants
    }
  end

  private

  def runtime_snapshots
    conversations_scope
      .where("additional_attributes ? 'assistant_runtime'")
      .pluck(Arel.sql("additional_attributes -> 'assistant_runtime'"))
      .map { |json| json.is_a?(Hash) ? json : {} }
  end

  def conversations_scope
    scope = @account.conversations.where(created_at: @since..@until_at)
    return scope if @assistant_id.blank?

    scope.joins(inbox: :captain_inbox).where(captain_inboxes: { captain_assistant_id: @assistant_id })
  end

  def routing_breakdown(rows)
    counts = ROUTING_LABELS.index_with { 0 }
    rows.each do |runtime|
      label = runtime['last_routing_decision'].to_s
      counts[label] += 1 if counts.key?(label)
    end
    counts
  end

  def confidence_buckets(rows)
    counts = CONFIDENCE_BUCKETS.keys.index_with { 0 }
    rows.each do |runtime|
      confidence = runtime.dig('last_faq_lookup', 'confidence')
      next if confidence.blank?

      bucket = CONFIDENCE_BUCKETS.find { |_, range| range.cover?(confidence.to_f) }
      counts[bucket.first] += 1 if bucket
    end
    counts
  end

  def approvals_breakdown
    scope = Captain::ApprovalRequest.where(
      account_id: @account.id,
      created_at: @since..@until_at
    )
    scope = scope.where(assistant_id: @assistant_id) if @assistant_id.present?
    APPROVAL_STATUSES.index_with { |status| scope.where(status: Captain::ApprovalRequest.statuses[status]).count }
  end

  def escalations_stats(rows)
    pending = rows.count { |r| r['pending_human_interaction'].present? }
    handed_off = rows.count { |r| r['last_routing_decision'] == 'human' }
    {
      pending_human_interaction: pending,
      handed_off_total: handed_off,
      handoff_rate: rows.size.positive? ? (handed_off.to_f / rows.size).round(3) : 0.0
    }
  end

  def top_assistants
    CaptainInbox
      .joins(inbox: :conversations)
      .where(conversations: { account_id: @account.id, created_at: @since..@until_at })
      .group(:captain_assistant_id)
      .order(Arel.sql('COUNT(conversations.id) DESC'))
      .limit(5)
      .count('conversations.id')
      .filter_map { |assistant_id, total| assistant_summary(assistant_id, total) }
  end

  def assistant_summary(assistant_id, total)
    assistant = Captain::Assistant.find_by(id: assistant_id)
    return nil if assistant.blank?

    { id: assistant.id, name: assistant.name, conversations: total }
  end
end
