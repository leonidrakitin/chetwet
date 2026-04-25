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

      it 'filters events by event_type list' do
        create_event(seq: 1, type: 'outgoing_message')
        create_event(seq: 2, type: 'tool_start', payload: { 'tool' => 'faq' })
        create_event(seq: 3, type: 'decision_selected', payload: { 'decision_domain' => 'handoff' })

        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/captain_trace_events",
            params: { event_type: 'tool_start,decision_selected' },
            headers: admin.create_new_auth_token, as: :json

        types = json_response[:events].map { |e| e[:event_type] }
        expect(types).to contain_exactly('tool_start', 'decision_selected')
      end

      it 'expands decision_* shortcut to all decision event types' do
        create_event(seq: 1, type: 'outgoing_message')
        create_event(seq: 2, type: 'decision_selected', payload: { 'decision_domain' => 'handoff' })
        create_event(seq: 3, type: 'decision_rejected', payload: { 'decision_domain' => 'tool_choice' })
        create_event(seq: 4, type: 'escalation_decision', payload: { 'decision_domain' => 'handoff' })

        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/captain_trace_events",
            params: { event_type: 'decision_*' },
            headers: admin.create_new_auth_token, as: :json

        types = json_response[:events].map { |e| e[:event_type] }
        expect(types).to contain_exactly('decision_selected', 'decision_rejected', 'escalation_decision')
      end

      it 'attaches a decision summary on decision events' do
        create_event(
          seq: 1,
          type: 'decision_selected',
          payload: {
            'decision_domain' => 'delayed_send',
            'decision_name' => 'schedule_outbound_message',
            'selected' => true,
            'reasoning_summary' => 'Customer asked for follow-up tomorrow',
            'scheduled_for' => '2026-04-26T09:00:00Z',
            'delay_seconds' => 86_400
          }
        )

        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/captain_trace_events",
            headers: admin.create_new_auth_token, as: :json

        event = json_response[:events].first
        expect(event[:summary]).to include(
          decision_domain: 'delayed_send',
          decision_name: 'schedule_outbound_message',
          selected: true,
          scheduled_for: '2026-04-26T09:00:00Z',
          delay_seconds: 86_400
        )
      end

      it 'returns prompt_snapshot events without breaking the existing payload contract' do
        create_event(
          seq: 1,
          type: 'prompt_snapshot',
          payload: {
            'agent' => 'orchestrator',
            'model' => 'gpt-4o',
            'system_prompt' => 'Be helpful.',
            'message_count' => 2,
            'messages' => [{ 'role' => 'user', 'content' => 'Hi' }],
            'tool_instructions' => [{ 'name' => 'escalate_to_human', 'description' => 'Hand off to human' }]
          }
        )

        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/captain_trace_events",
            headers: admin.create_new_auth_token, as: :json

        event = json_response[:events].find { |e| e[:event_type] == 'prompt_snapshot' }
        expect(event).to be_present
        expect(event[:payload]).to include(
          agent: 'orchestrator',
          model: 'gpt-4o',
          system_prompt: 'Be helpful.',
          message_count: 2
        )
        expect(event[:payload][:messages].first).to include(role: 'user', content: 'Hi')
        expect(event[:payload][:tool_instructions].first).to include(name: 'escalate_to_human')
      end

      it 'includes raw_payload alias when include=raw_payload is requested' do
        create_event(payload: { 'tool' => 'faq', 'result' => { 'policy' => 'answer' } }, type: 'tool_complete')

        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/captain_trace_events",
            params: { include: 'raw_payload' },
            headers: admin.create_new_auth_token, as: :json

        event = json_response[:events].first
        expect(event[:raw_payload]).to eq(event[:payload])
      end
    end
  end
end
