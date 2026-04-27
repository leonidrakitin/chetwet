# frozen_string_literal: true

# Schedules a Captain-initiated follow-up message for the current contact.
# Creates an ad-hoc NotificationTemplate + scheduled delivery consumed by
# NotificationTemplates::ProcessScheduledJob.
class Captain::Tools::ScheduleFollowUpTool < Captain::Tools::BasePublicTool
  risk_level :write

  MIN_DELAY_MINUTES = 1
  MAX_DELAY_MINUTES = 60 * 24 * 7

  description 'Schedule a follow-up message to the current contact (e.g. reminder, nudge). ' \
              'Delivery is handled asynchronously at the specified delay.'
  param :message, type: 'string', desc: 'Exact follow-up text to send to the customer (required)'
  param :delay_minutes, type: 'integer', desc: 'When to send, in minutes from now (1..10080)'
  param :reason, type: 'string', desc: 'Optional internal reason for the follow-up', required: false

  def perform(tool_context, message:, delay_minutes:, reason: nil)
    log_start(tool_context, message, delay_minutes, reason)

    delay = validate_delay!(delay_minutes)
    text = message.to_s.strip
    return log_failure('blank_message', 'message must not be empty') if text.blank?

    conversation = find_conversation(tool_context.state)
    contact = find_contact(tool_context.state) || conversation&.contact
    return log_failure('no_conversation', 'No conversation context for follow-up') if conversation.blank?
    return log_failure('no_contact', 'No contact context for follow-up') if contact.blank?

    delivery = schedule_delivery!(conversation, contact, text, delay, reason)
    log_success(delivery, delay)
    success_result(delivery, delay)
  rescue ArgumentError => e
    log_failure('invalid_argument', e.message)
  rescue ActiveRecord::RecordInvalid => e
    log_failure('record_invalid', "Failed to schedule follow-up: #{e.message}")
  end

  private

  def validate_delay!(minutes)
    value = minutes.to_i
    return value if value.between?(MIN_DELAY_MINUTES, MAX_DELAY_MINUTES)

    raise ArgumentError, "delay_minutes must be between #{MIN_DELAY_MINUTES} and #{MAX_DELAY_MINUTES}"
  end

  def schedule_delivery!(conversation, contact, text, delay_minutes, reason)
    template = build_template!(conversation, text, reason)
    template.deliveries.create!(
      account: template.account,
      contact: contact,
      conversation: conversation,
      status: 'scheduled',
      trigger_type: 'captain_follow_up',
      scheduled_for: delay_minutes.minutes.from_now,
      metadata: { reason: reason, assistant_id: @assistant.id }.compact
    )
  end

  def build_template!(conversation, text, reason)
    NotificationTemplate.create!(
      account: conversation.account,
      inbox: conversation.inbox,
      name: "Captain follow-up ##{conversation.display_id} @ #{Time.current.iso8601}",
      description: reason.presence || 'Captain ad-hoc follow-up',
      template_type: 'event',
      event_type: 'captain_follow_up',
      enabled: true,
      messages: [{ text: text }],
      schedule: {},
      audience: {},
      conditions: {},
      limits: { 'bypass_global_limits' => true },
      metadata: { 'captain_ad_hoc' => true, 'assistant_id' => @assistant.id }
    )
  end

  def success_result(delivery, delay_minutes)
    {
      status: 'scheduled',
      delivery_id: delivery.id,
      scheduled_for: delivery.scheduled_for.iso8601,
      delay_minutes: delay_minutes
    }
  end

  def error_result(message)
    { status: 'error', error: message }
  end

  # Structured logs let ops trace the full path tool_invoked → delivery_created →
  # scheduled_for → dispatched without diff'ing the trace recorder payload. The
  # `[Captain V2][schedule_follow_up]` prefix is grep-friendly and pairs with the
  # NotificationTemplate dispatcher's own logs by delivery_id.
  def log_start(tool_context, message, delay_minutes, reason)
    state = tool_context&.state || {}
    Rails.logger.info(
      '[Captain V2][schedule_follow_up] start ' \
      "assistant_id=#{@assistant&.id} " \
      "conversation_id=#{state.dig(:conversation, :id) || state.dig('conversation', 'id')} " \
      "contact_id=#{state.dig(:contact, :id) || state.dig('contact', 'id')} " \
      "delay_minutes=#{delay_minutes.inspect} " \
      "reason=#{reason.to_s.truncate(120).inspect} " \
      "message_preview=#{message.to_s.truncate(120).inspect}"
    )
  end

  def log_success(delivery, delay_minutes)
    Rails.logger.info(
      '[Captain V2][schedule_follow_up] success ' \
      "assistant_id=#{@assistant&.id} " \
      "notification_template_id=#{delivery.notification_template_id} " \
      "delivery_id=#{delivery.id} " \
      "scheduled_for=#{delivery.scheduled_for&.iso8601} " \
      "delay_minutes=#{delay_minutes}"
    )
  end

  def log_failure(reason_code, message)
    Rails.logger.warn(
      '[Captain V2][schedule_follow_up] failure ' \
      "assistant_id=#{@assistant&.id} " \
      "reason_code=#{reason_code} " \
      "message=#{message.to_s.truncate(300).inspect}"
    )
    error_result(message)
  end
end
