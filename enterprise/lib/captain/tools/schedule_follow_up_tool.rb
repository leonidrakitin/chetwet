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
    delay = validate_delay!(delay_minutes)
    text = message.to_s.strip
    return error_result('message must not be empty') if text.blank?

    conversation = find_conversation(tool_context.state)
    contact = find_contact(tool_context.state) || conversation&.contact
    return error_result('No conversation context for follow-up') if conversation.blank?
    return error_result('No contact context for follow-up') if contact.blank?

    delivery = schedule_delivery!(conversation, contact, text, delay, reason)
    success_result(delivery, delay)
  rescue ArgumentError => e
    error_result(e.message)
  rescue ActiveRecord::RecordInvalid => e
    error_result("Failed to schedule follow-up: #{e.message}")
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
end
