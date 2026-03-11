require 'rails_helper'

RSpec.describe 'YClients Marketplace Integration API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }

  before do
    allow(InstallationConfig).to receive(:find_by).and_call_original
    allow(InstallationConfig).to receive(:find_by).with(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS').and_return(nil)
  end

  describe 'GET /api/v1/accounts/:account_id/integrations/yclients_marketplace/status' do
    let!(:existing_hook) do
      create(
        :integrations_hook,
        account: account,
        app_id: 'yclients',
        settings: {
          'partner_token' => 'partner-token',
          'user_token' => 'user-token',
          'company_id' => '111'
        }
      )
    end

    it 'returns already connected salons for the selected account' do
      get "/api/v1/accounts/#{account.id}/integrations/yclients_marketplace/status",
          params: { salon_ids: [111, 222] },
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        'status' => 'not_connected',
        'connected_salon_ids' => [111]
      )
    end
  end

  describe 'POST /api/v1/accounts/:account_id/integrations/yclients_marketplace/connect' do
    let(:callback_service) { instance_double(Crm::Yclients::Marketplace::CallbackService) }

    before do
      allow(Crm::Yclients::Marketplace::CallbackService).to receive(:new).and_return(callback_service)
      allow(callback_service).to receive(:call) do
        [111, 222].each do |salon_id|
          create(
            :integrations_hook,
            account: account,
            app_id: 'yclients',
            settings: {
              'partner_token' => 'partner-token',
              'user_token' => 'user-token',
              'company_id' => salon_id.to_s
            }
          )
        end

        { success: [111, 222], errors: [] }
      end
    end

    it 'connects salons immediately and returns the connected ids' do
      post "/api/v1/accounts/#{account.id}/integrations/yclients_marketplace/connect",
           params: { salon_ids: [111, 222] },
           headers: agent.create_new_auth_token,
           as: :json

      expect(Crm::Yclients::Marketplace::CallbackService).to have_received(:new).with(
        account_id: account.id,
        salon_ids: [111, 222]
      )
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('connected')
      expect(response.parsed_body['connected_salon_ids']).to contain_exactly(111, 222)
    end

    it 'returns already connected when all salons are already linked' do
      create(
        :integrations_hook,
        account: account,
        app_id: 'yclients',
        settings: {
          'partner_token' => 'partner-token',
          'user_token' => 'user-token',
          'company_id' => '111'
        }
      )

      post "/api/v1/accounts/#{account.id}/integrations/yclients_marketplace/connect",
           params: { salon_ids: [111] },
           headers: agent.create_new_auth_token,
           as: :json

      expect(Crm::Yclients::Marketplace::CallbackService).not_to have_received(:new)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        'status' => 'already_connected',
        'connected_salon_ids' => [111]
      )
    end
  end

  describe 'POST /api/v1/accounts/:account_id/integrations/yclients_marketplace/payment' do
    let!(:integration) { create(:yclients_integration, account: account, salon_id: 111) }
    let(:notifications_service) { instance_double(Crm::Yclients::Marketplace::NotificationsService) }

    before do
      allow(Crm::Yclients::Marketplace::NotificationsService).to receive(:new).and_return(notifications_service)
      allow(notifications_service).to receive(:notify_payment!).and_return({ 'success' => true, 'data' => {} })
    end

    it 'sends a payment notification for the connected salon' do
      post "/api/v1/accounts/#{account.id}/integrations/yclients_marketplace/payment",
           params: {
             salon_id: integration.salon_id,
             payment_sum: 1299.50,
             currency_iso: 'RUB',
             payment_date: '2026-03-07T12:00:00Z',
             period_from: '2026-03-07',
             period_to: '2026-04-06'
           },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(notifications_service).to have_received(:notify_payment!).with(
        {
          salon_id: 111,
          payment_sum: 1299.5,
          currency_iso: 'RUB',
          payment_date: '2026-03-07T12:00:00Z',
          period_from: '2026-03-07',
          period_to: '2026-04-06'
        },
        application_id: nil
      )
    end
  end

  describe 'POST /api/v1/accounts/:account_id/integrations/yclients_marketplace/payment/refund/:payment_id' do
    let!(:integration) { create(:yclients_integration, account: account, salon_id: 111) }
    let(:notifications_service) { instance_double(Crm::Yclients::Marketplace::NotificationsService) }

    before do
      allow(Crm::Yclients::Marketplace::NotificationsService).to receive(:new).and_return(notifications_service)
      allow(notifications_service).to receive(:refund_payment!).and_return({ 'success' => true, 'data' => {} })
    end

    it 'sends a refund notification for the connected salon' do
      post "/api/v1/accounts/#{account.id}/integrations/yclients_marketplace/payment/refund/987",
           params: { salon_id: integration.salon_id },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(notifications_service).to have_received(:refund_payment!).with(
        payment_id: '987',
        application_id: nil
      )
    end

    it 'returns not found for a salon that is not connected to the account' do
      post "/api/v1/accounts/#{account.id}/integrations/yclients_marketplace/payment/refund/987",
           params: { salon_id: 999 },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:not_found)
      expect(notifications_service).not_to have_received(:refund_payment!)
    end
  end
end
