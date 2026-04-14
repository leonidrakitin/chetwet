# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::Accounts::Services::ReportsController, type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let!(:provider) { ServiceProvider.create!(account: account, name: 'Legacy Schedule Provider') }
  let(:report_date) { Date.commercial(2026, 1, 2) }

  before do
    provider.create_provider_schedule!(
      inherit_account_schedule: false,
      timezone: 'UTC',
      working_hours: {
        'tuesday' => {
          enabled: true,
          slots: [{ start: '09:00', end: '18:00' }]
        }.to_json
      }
    )
  end

  describe 'GET /api/v1/accounts/{account.id}/services/reports' do
    it 'returns provider utilization for stringified day configs' do
      get "/api/v1/accounts/#{account.id}/services/reports",
          params: { start_date: report_date.to_s, end_date: report_date.to_s },
          headers: administrator.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['provider_utilization']).to contain_exactly(
        include(
          'id' => provider.id,
          'name' => 'Legacy Schedule Provider',
          'total_bookings' => 0,
          'total_minutes' => 0,
          'utilization_rate' => 0.0
        )
      )
    end
  end
end
