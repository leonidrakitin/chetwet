class Captain::Trace::Recorder
  MAX_PAYLOAD_BYTES = 32_768

  attr_reader :session_id

  def initialize(conversation:, assistant:, source: nil)
    @conversation = conversation
    @assistant = assistant
    @source = source
    @account = conversation&.account
    @session_id = build_session_id
    @buffer = []
    @sequence = 0
    @enabled = resolve_enabled
  end

  def enabled?
    @enabled
  end

  def record(event_type, payload = {})
    return unless enabled?
    return if event_type.blank?

    @buffer << {
      event_type: event_type.to_s,
      sequence: next_sequence,
      payload: sanitize_payload(payload)
    }
  rescue StandardError => e
    Rails.logger.warn("[Captain::Trace::Recorder] record failed (#{event_type}): #{e.class}: #{e.message}")
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

  def redact_pii(value)
    case value
    when Hash then value.transform_values { |v| redact_pii(v) }
    when Array then value.map { |v| redact_pii(v) }
    when String then value.gsub(EMAIL_RE, '[redacted_email]').gsub(PHONE_RE, '[redacted_phone]')
    else value
    end
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
end
