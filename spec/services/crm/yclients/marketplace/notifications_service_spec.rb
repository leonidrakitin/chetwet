require 'rails_helper'

RSpec.describe Crm::Yclients::Marketplace::NotificationsService do
  let(:service) { described_class.new }

  before do
    allow(InstallationConfig).to receive(:find_by).and_call_original
    allow(InstallationConfig).to receive(:find_by)
      .with(name: 'YCLIENTS_MARKETPLACE_PARTNER_TOKEN')
      .and_return(instance_double(InstallationConfig, value: 'partner-token'))
    allow(InstallationConfig).to receive(:find_by)
      .with(name: 'YCLIENTS_MARKETPLACE_APPLICATION_ID')
      .and_return(instance_double(InstallationConfig, value: '12'))
  end

  describe '#notify_payment!' do
    it 'posts successful payment notifications to YClients' do
      response = instance_double(HTTParty::Response, success?: true, parsed_response: { 'success' => true, 'data' => {} })

      expect(described_class).to receive(:post).with(
        'https://api.yclients.com/api/v1/marketplace/partner/payment',
        hash_including(
          headers: hash_including('Authorization' => 'Bearer partner-token')
        )
      ).and_return(response)

      result = service.notify_payment!(
        {
          salon_id: 111,
          payment_sum: 999,
          currency_iso: 'RUB',
          payment_date: '2026-03-07T12:00:00Z',
          period_from: '2026-03-07',
          period_to: '2026-04-06'
        }
      )

      expect(result).to eq({ 'success' => true, 'data' => {} })
    end
  end

  describe '#refund_payment!' do
    it 'posts refund notifications to YClients' do
      response = instance_double(HTTParty::Response, success?: true, parsed_response: { 'success' => true, 'data' => {} })

      expect(described_class).to receive(:post).with(
        'https://api.yclients.com/api/v1/marketplace/partner/payment/refund/987',
        hash_including(
          headers: hash_including('Authorization' => 'Bearer partner-token')
        )
      ).and_return(response)

      result = service.refund_payment!(payment_id: 987)

      expect(result).to eq({ 'success' => true, 'data' => {} })
    end
  end
end
