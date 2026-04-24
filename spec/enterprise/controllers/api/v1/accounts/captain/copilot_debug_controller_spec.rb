require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::CopilotDebug', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:copilot_thread) { create(:captain_copilot_thread, account: account, user: admin, assistant: assistant) }

  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  describe 'GET /api/v1/accounts/{account.id}/captain/copilot_debug/:id' do
    context 'when the user is not authenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/captain/copilot_debug/#{copilot_thread.id}", as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when the user is an agent' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/captain/copilot_debug/#{copilot_thread.id}",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when the user is an administrator' do
      before do
        create(:captain_copilot_message,
               account: account,
               copilot_thread: copilot_thread,
               message_type: :assistant,
               message: { content: 'Hello there' })
      end

      it 'returns the debug payload' do
        get "/api/v1/accounts/#{account.id}/captain/copilot_debug/#{copilot_thread.id}",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response[:thread][:id]).to eq(copilot_thread.id)
        expect(json_response[:messages].size).to eq(1)
        expect(json_response[:messages].first[:message][:content]).to eq('Hello there')
      end

      it 'returns 404 when the thread does not exist' do
        get "/api/v1/accounts/#{account.id}/captain/copilot_debug/0",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:not_found)
      end

      it 'returns 404 when the thread belongs to a different account' do
        other_account = create(:account)
        other_thread = create(:captain_copilot_thread, account: other_account)

        get "/api/v1/accounts/#{account.id}/captain/copilot_debug/#{other_thread.id}",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
