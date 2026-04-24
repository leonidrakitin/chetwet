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

    scope.ordered.map do |event|
      {
        id: event.id,
        session_id: event.session_id,
        sequence: event.sequence,
        event_type: event.event_type,
        payload: event.payload,
        source_message_id: event.source_message_id,
        created_at: event.created_at.to_fs(:iso8601)
      }
    end
  end
end
