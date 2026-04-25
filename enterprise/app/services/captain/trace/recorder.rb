class Captain::Trace::Recorder
  MAX_PAYLOAD_BYTES = 32_768
  MAX_REASONING_CHARS = 1_000

  attr_reader :session_id

  def initialize(conversation:, assistant:, source: nil)
    @conversation = conversation
    @assistant = assistant
    @source = source
    @account = conversation&.account
    @session_id = build_session_id
    @buffer = []
    @sequence = 0
    @timers = {}
    @run_started_at = nil
    @enabled = resolve_enabled
  end

  def enabled?
    @enabled
  end

  def record(event_type, payload = {})
    return unless enabled?
    return if event_type.blank?

    @run_started_at ||= Time.current if event_type.to_s == 'run_started'

    @buffer << {
      event_type: event_type.to_s,
      sequence: next_sequence,
      payload: sanitize_payload(payload)
    }
  rescue StandardError => e
    Rails.logger.warn("[Captain::Trace::Recorder] record failed (#{event_type}): #{e.class}: #{e.message}")
  end

  # decision_domain examples:
  #   notification_template, delayed_send, handoff, tool_choice, citation, autonomy
  # selected: true (selected), false (rejected), nil (evaluated/deferred)
  def record_decision(event_type, domain:, name:, **opts)
    extra = opts[:extra] || {}
    payload = {
      decision_domain: domain.to_s,
      decision_name: name.to_s,
      selected: opts[:selected],
      reasoning_summary: truncate_reasoning(opts[:reasoning_summary]),
      inputs: opts[:inputs],
      alternatives_considered: opts[:alternatives_considered],
      policy_constraints: opts[:policy_constraints],
      scheduled_for: opts[:scheduled_for],
      delay_seconds: opts[:delay_seconds],
      template_id: opts[:template_id],
      template_name: opts[:template_name],
      correlation_id: opts[:correlation_id]
    }.merge(extra).compact

    record(event_type, payload)
  end

  def record_knowledge_hit(source:, **opts)
    extra = opts[:extra] || {}
    snippet = opts[:snippet]
    payload = {
      source: source.to_s,
      query: opts[:query].to_s.presence,
      rank: opts[:rank],
      score: opts[:score],
      reference: opts[:reference],
      snippet: snippet.to_s.presence ? snippet.to_s.truncate(400) : nil
    }.merge(extra).compact

    record(:knowledge_hit, payload)
  end

  def measure(event_type, payload = {}, correlation_id: nil)
    started = Time.current
    yield.tap do |result|
      ms = ((Time.current - started) * 1000).round
      record(event_type, payload.merge(duration_ms: ms, correlation_id: correlation_id).compact)
      next result
    end
  rescue StandardError
    ms = ((Time.current - started) * 1000).round
    record(event_type, payload.merge(duration_ms: ms, correlation_id: correlation_id, errored: true).compact)
    raise
  end

  def start_timer(token)
    return unless enabled?

    @timers[token.to_s] = Time.current
  end

  def stop_timer(token)
    started = @timers.delete(token.to_s)
    return nil if started.blank?

    ((Time.current - started) * 1000).round
  end

  def run_duration_ms
    return nil if @run_started_at.blank?

    ((Time.current - @run_started_at) * 1000).round
  end

  def new_correlation_id
    SecureRandom.hex(6)
  end

  def flush_to(source_message: nil)
    return if @buffer.empty?

    rows = @buffer.map { |event| build_row(event, source_message) }
    Captain::TraceEvent.insert_all(rows) if rows.any? # rubocop:disable Rails/SkipsModelValidations
    @buffer.clear
  rescue StandardError => e
    Rails.logger.warn("[Captain::Trace::Recorder] flush failed: #{e.class}: #{e.message}")
    @buffer.clear
  end

  def discard!
    @buffer.clear
  end

  private

  def resolve_enabled
    return false if @conversation.blank? || @account.blank?

    @account.feature_enabled?('captain_trace_events')
  end

  def build_session_id
    run_token = SecureRandom.hex(4)
    base = [@account&.id, @conversation&.display_id, run_token].compact.join('_')
    base.presence || run_token
  end

  def next_sequence
    @sequence += 1
    @sequence
  end

  def build_row(event, source_message)
    now = Time.current
    {
      account_id: @account.id,
      conversation_id: @conversation.id,
      assistant_id: @assistant&.id,
      session_id: @session_id,
      source_message_id: source_message&.id,
      event_type: event[:event_type],
      sequence: event[:sequence],
      payload: event[:payload],
      created_at: now
    }
  end

  def sanitize_payload(payload)
    hash = payload.is_a?(Hash) ? payload.deep_stringify_keys : { 'value' => payload.to_s }
    redacted = redact_pii(hash)
    truncate_payload(redacted)
  end

  EMAIL_RE = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i
  PHONE_RE = /(?<!\d)(\+?\d[\d\s().-]{7,}\d)(?!\d)/
  ISO_TIMESTAMP_RE = /\A\d{4}-\d{2}-\d{2}(?:[T\s]\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:?\d{2})?)?\z/

  def redact_pii(value)
    case value
    when Hash then value.transform_values { |v| redact_pii(v) }
    when Array then value.map { |v| redact_pii(v) }
    when String then redact_pii_string(value)
    else value
    end
  end

  def redact_pii_string(value)
    return value if value.match?(ISO_TIMESTAMP_RE)

    value.gsub(EMAIL_RE, '[redacted_email]').gsub(PHONE_RE, '[redacted_phone]')
  end

  def truncate_payload(payload)
    json = payload.to_json
    return payload if json.bytesize <= MAX_PAYLOAD_BYTES

    {
      'truncated' => true,
      'size_bytes' => json.bytesize,
      'preview' => json.byteslice(0, MAX_PAYLOAD_BYTES)
    }
  end

  def truncate_reasoning(value)
    return nil if value.blank?

    value.to_s.truncate(MAX_REASONING_CHARS)
  end
end
