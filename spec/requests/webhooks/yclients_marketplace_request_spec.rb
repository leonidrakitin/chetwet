require 'rails_helper'

RSpec.describe 'YClients Marketplace Webhooks', type: :request do
  let(:account) { create(:account) }
  let!(:integration) { create(:yclients_integration, account: account, salon_id: 111, bearer_token: 'old-token') }
  let!(:hook) do
    create(
      :integrations_hook,
      account: account,
      app_id: 'yclients',
      status: :enabled,
      settings: {
        'partner_token' => 'partner-token',
        'user_token' => 'old-token',
        'company_id' => integration.salon_id.to_s
      }
    )
  end
  let!(:secret) do
    create(:installation_config, name: 'YCLIENTS_MARKETPLACE_WEBHOOK_SECRET', value: 'shared-secret')
  end

  before do
    allow(InstallationConfig).to receive(:find_by).and_call_original
    allow(InstallationConfig).to receive(:find_by).with(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS').and_return(nil)
  end

  it 'revokes the integration and disables the matching hook' do
    post '/webhooks/yclients/marketplace',
         params: { event: 'integration_revoked', salon_id: integration.salon_id }.to_json,
         headers: {
           'CONTENT_TYPE' => 'application/json',
           'X-Yclients-Signature' => secret.value
         }

    expect(response).to have_http_status(:ok)
    expect(integration.reload).to be_revoked
    expect(hook.reload).to be_disabled
  end

  it 'updates the bearer token and enables the matching hook again' do
    integration.update!(status: :revoked)
    hook.update!(status: :disabled)

    post '/webhooks/yclients/marketplace',
         params: {
           event: 'integration_activated',
           salon_id: integration.salon_id,
           bearer_token: 'new-token'
         }.to_json,
         headers: {
           'CONTENT_TYPE' => 'application/json',
           'X-Yclients-Signature' => secret.value
         }

    expect(response).to have_http_status(:ok)
    expect(integration.reload.bearer_token).to eq('new-token')
    expect(integration).to be_active
    expect(hook.reload.settings['user_token']).to eq('new-token')
    expect(hook).to be_enabled
  end
end
