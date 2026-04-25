class Api::V1::Accounts::Conversations::CaptainTraceEventsController < Api::V1::Accounts::Conversations::BaseController
  before_action :ensure_admin

  def index
    render json: {
      outgoing_messages: outgoing_messages_payload,
      events: events_payload
    }
  end

  private

  def ensure_admin
    render json: { error: 'Unauthorized' }, status: :unauthorized unless Current.user&.administrator?
  end

  def outgoing_messages_payload
    @conversation.messages
                 .where(message_type: :outgoing, sender_type: 'Captain::Assistant')
                 .order(created_at: :asc)
                 .map do |message|
      {
        id: message.id,
        content: message.content.to_s.truncate(300),
        created_at: message.created_at.to_fs(:iso8601),
        agent_name: message.additional_attributes&.dig('agent_name')
      }
    end
  end

  def events_payload
    scope = Captain::TraceEvent.for_conversation(@conversation.id)
    scope = scope.where(source_message_id: params[:message_id]) if params[:message_id].present?
    scope = apply_event_type_filter(scope)

    payload_mode = include_raw_payload? ? :raw : :default
    scope.ordered.map { |event| serialize_event(event, payload_mode) }
  end

  def apply_event_type_filter(scope)
    raw = parse_event_type_param
    return scope if raw.empty?

    types = expand_event_types(raw)
    types.empty? ? scope.none : scope.by_event_types(types)
  end

  def parse_event_type_param
    Array(params[:event_type]).flat_map { |v| v.to_s.split(',') }.map(&:strip).reject(&:blank?)
  end

  def expand_event_types(raw)
    expanded = raw.flat_map do |token|
      if %w[decision_* decisions].include?(token)
        Captain::TraceEvent::DECISION_EVENT_TYPES
      else
        [token]
      end
    end
    expanded.uniq.select { |t| Captain::TraceEvent::EVENT_TYPES.include?(t) }
  end

  def include_raw_payload?
    Array(params[:include]).flat_map { |v| v.to_s.split(',') }.map(&:strip).include?('raw_payload')
  end

  def serialize_event(event, payload_mode)
    body = {
      id: event.id,
      session_id: event.session_id,
      sequence: event.sequence,
      event_type: event.event_type,
      payload: event.payload,
      source_message_id: event.source_message_id,
      created_at: event.created_at.to_fs(:iso8601)
    }
    body[:summary] = decision_summary(event) if event.payload.is_a?(Hash) && Captain::TraceEvent::DECISION_EVENT_TYPES.include?(event.event_type)
    body[:raw_payload] = event.payload if payload_mode == :raw
    body
  end

  def decision_summary(event)
    payload = event.payload
    {
      decision_domain: payload['decision_domain'],
      decision_name: payload['decision_name'],
      selected: payload['selected'],
      reasoning_summary: payload['reasoning_summary'],
      template_id: payload['template_id'],
      template_name: payload['template_name'],
      scheduled_for: payload['scheduled_for'],
      delay_seconds: payload['delay_seconds']
    }.compact
  end
end
