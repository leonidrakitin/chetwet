require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Conversations::CaptainTraceEvents', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  let(:outgoing_message) do
    create(:message, conversation: conversation, account: account, inbox: inbox,
                     message_type: :outgoing, sender: assistant, content: 'Hi there')
  end

  def create_event(message_id: outgoing_message.id, session: 'sess_1', seq: 1, type: 'outgoing_message', payload: { 'content' => 'Hi there' })
    Captain::TraceEvent.create!(
      account: account, conversation: conversation, assistant: assistant,
      source_message_id: message_id, session_id: session, sequence: seq,
      event_type: type, payload: payload
    )
  end

  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  describe 'GET /api/v1/accounts/:account_id/conversations/:conversation_id/captain_trace_events' do
    context 'when the user is not authenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/captain_trace_events", as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when the user is an agent' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/captain_trace_events",
            headers: agent.create_new_auth_token, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when the user is an administrator' do
      it 'returns outgoing messages and events' do
        create_event

        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/captain_trace_events",
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(json_response[:outgoing_messages].size).to eq(1)
        expect(json_response[:outgoing_messages].first[:id]).to eq(outgoing_message.id)
        expect(json_response[:events].size).to eq(1)
        expect(json_response[:events].first[:event_type]).to eq('outgoing_message')
      end

      it 'filters events by message_id when provided' do
        create_event
        other_message = create(:message, conversation: conversation, account: account, inbox: inbox,
                                         message_type: :outgoing, sender: assistant, content: 'Other')
        create_event(message_id: other_message.id, session: 'sess_2', payload: {})

        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/captain_trace_events",
            params: { message_id: outgoing_message.id },
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(json_response[:events].size).to eq(1)
        expect(json_response[:events].first[:source_message_id]).to eq(outgoing_message.id)
      end
    end
  end
end
