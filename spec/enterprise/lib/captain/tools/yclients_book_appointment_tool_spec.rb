require 'rails_helper'

RSpec.describe Captain::Tools::YclientsBookAppointmentTool, type: :model do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:tool) { described_class.new(assistant) }
  let(:contact) { create(:contact, :with_email, :with_phone_number, account: account, name: 'Jane Doe') }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:hook) do
    create(
      :integrations_hook,
      account: account,
      app_id: 'yclients',
      status: :enabled,
      settings: {
        'partner_token' => 'partner-token',
        'user_token' => 'user-token',
        'company_id' => '101'
      }
    )
  end
  let(:booking_client) { instance_double(Crm::Yclients::Api::BookingClient) }
  let(:clients_client) { instance_double(Crm::Yclients::Api::ClientsClient) }
  let(:tool_context) do
    Struct.new(:state).new(
      {
        contact: { id: contact.id },
        conversation: {
          id: conversation.id,
          display_id: conversation.display_id,
          additional_attributes: {}
        }
      }
    )
  end

  before do
    allow(InstallationConfig).to receive(:find_by).and_call_original
    allow(InstallationConfig).to receive(:find_by).with(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS').and_return(nil)
    hook
    allow(Crm::Yclients::Api::BookingClient).to receive(:new).and_return(booking_client)
    allow(Crm::Yclients::Api::ClientsClient).to receive(:new).and_return(clients_client)
  end

  it 'books with the API-compliant appointments payload and stores an inferred client id' do
    allow(clients_client).to receive(:find_by_phone).with(contact.phone_number).and_return({ 'id' => 77 })
    allow(booking_client).to receive(:check_booking).and_return({ 'success' => true })
    allow(booking_client).to receive(:create_booking).and_return([{ 'record_id' => 555 }])

    result = tool.perform(
      tool_context,
      company_id: '101',
      staff_id: '10',
      service_ids: '1,2',
      datetime: '2026-03-08 14:00'
    )

    expect(result).to include('Record ID: 555')
    expect(booking_client).to have_received(:check_booking).with(
      'appointments' => [
        {
          'id' => 1,
          'services' => [1, 2],
          'staff_id' => 10,
          'datetime' => '2026-03-08 14:00'
        }
      ]
    )
    expect(booking_client).to have_received(:create_booking).with(
      hash_including(
        'phone' => contact.phone_number,
        'fullname' => 'Jane Doe',
        'email' => contact.email,
        'appointments' => [
          {
            'id' => 1,
            'services' => [1, 2],
            'staff_id' => 10,
            'datetime' => '2026-03-08 14:00'
          }
        ]
      )
    )
    expect(contact.reload.additional_attributes.dig('external', 'yclients_ids', '101')).to eq('77')
  end

  it 'asks for company_id when multiple salons are connected and the state is ambiguous' do
    create(
      :integrations_hook,
      account: account,
      app_id: 'yclients',
      status: :enabled,
      settings: {
        'partner_token' => 'partner-token-2',
        'user_token' => 'user-token-2',
        'company_id' => '202'
      }
    )

    result = tool.perform(
      tool_context,
      staff_id: '10',
      service_ids: '1',
      datetime: '2026-03-08 14:00'
    )

    expect(result).to eq('YClients hook is ambiguous or not configured. Provide company_id when multiple salons are connected.')
  end
end
