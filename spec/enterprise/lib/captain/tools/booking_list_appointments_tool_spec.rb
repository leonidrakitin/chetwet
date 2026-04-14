require 'rails_helper'

RSpec.describe Captain::Tools::BookingListAppointmentsTool do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:provider) { ServiceProvider.create!(account: account, name: 'Provider One') }
  let(:service) { Service.create!(account: account, name: 'Haircut', duration_minutes: 30, price: 50) }
  let(:booking) do
    ServiceBooking.create!(
      account: account,
      contact: contact,
      service_provider: provider,
      scheduled_at: 2.days.from_now
    )
  end

  let(:tool) { described_class.new(assistant) }
  let(:tool_context) { Struct.new(:state).new({ contact: { id: contact.id } }) }

  before do
    create(:integrations_hook, account: account, app_id: 'booking_manager')
    ServiceBookingItem.create!(
      service_booking: booking,
      service: service,
      position: 0,
      duration_minutes: service.duration_minutes,
      price: service.price
    )
    booking.calculate_total_duration
  end

  it 'returns upcoming bookings for the contact' do
    result = tool.perform(tool_context, scope: 'upcoming')
    payload = JSON.parse(result)

    expect(payload['data'].first['id']).to eq(booking.id)
  end
end
