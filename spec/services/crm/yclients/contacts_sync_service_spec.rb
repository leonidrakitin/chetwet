require 'rails_helper'

RSpec.describe Crm::Yclients::ContactsSyncService do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, :with_email, :with_phone_number, account: account) }
  let(:hook_one) do
    create(
      :integrations_hook,
      account: account,
      app_id: 'yclients',
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

  describe '#find_or_create_from_yclients' do
    it 'stores company-specific external ids without losing existing mappings' do
      first_service = described_class.new(account, hook_one)
      second_service = described_class.new(account, hook_two)

      first_service.find_or_create_from_yclients(
        'id' => 1001,
        'name' => contact.name,
        'phone' => contact.phone_number,
        'email' => contact.email
      )
      second_service.find_or_create_from_yclients(
        'id' => 2002,
        'name' => contact.name,
        'phone' => contact.phone_number,
        'email' => contact.email
      )

      external = contact.reload.additional_attributes.fetch('external')
      expect(external['yclients_ids']).to eq(
        '101' => '1001',
        '202' => '2002'
      )
      expect(external['yclients_id']).to eq('1001')
    end
  end
end
