require 'rails_helper'

RSpec.describe 'YClients Integration API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) do
    create(
      :contact,
      :with_email,
      :with_phone_number,
      account: account,
      additional_attributes: {
        'external' => {
          'yclients_ids' => {
            '101' => '1001',
            '202' => '2002'
          }
        }
      }
    )
  end
  let(:hook_one) do
    create(
      :integrations_hook,
      account: account,
      app_id: 'yclients',
      status: :enabled,
      settings: {
        'partner_token' => 'partner-101',
        'user_token' => 'user-101',
        'company_id' => '101'
      }
    )
  end
  let(:hook_two) do
    create(
      :integrations_hook,
      account: account,
      app_id: 'yclients',
      status: :enabled,
      settings: {
        'partner_token' => 'partner-202',
        'user_token' => 'user-202',
        'company_id' => '202'
      }
    )
  end

  before do
    allow(InstallationConfig).to receive(:find_by).and_call_original
    allow(InstallationConfig).to receive(:find_by).with(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS').and_return(nil)
  end

  describe 'GET /api/v1/accounts/:account_id/integrations/yclients/contacts/:contact_id/records' do
    it 'aggregates records across connected salons using company-specific ids' do
      hook_one
      hook_two
      client_one = instance_double(Crm::Yclients::Api::RecordsClient)
      client_two = instance_double(Crm::Yclients::Api::RecordsClient)

      allow(Crm::Yclients::Api::RecordsClient).to receive(:new)
        .with('partner-101', 'user-101', '101').and_return(client_one)
      allow(Crm::Yclients::Api::RecordsClient).to receive(:new)
        .with('partner-202', 'user-202', '202').and_return(client_two)
      allow(client_one).to receive(:get_by_client).with('1001').and_return([{ 'id' => 1, 'date' => '2026-03-07 10:00:00' }])
      allow(client_two).to receive(:get_by_client).with('2002').and_return([{ 'id' => 2, 'date' => '2026-03-08 10:00:00' }])

      get "/api/v1/accounts/#{account.id}/integrations/yclients/contacts/#{contact.id}/records",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['records'].pluck('company_id')).to contain_exactly('101', '202')
      expect(body['records'].pluck('id')).to contain_exactly(1, 2)
    end
  end
end
