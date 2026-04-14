require 'rails_helper'

RSpec.describe Captain::Tools::BookingUpdateAppointmentTool do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:provider) { ServiceProvider.create!(account: account, name: 'Provider One') }
  let(:new_provider) { ServiceProvider.create!(account: account, name: 'Provider Two') }
  let(:service) { Service.create!(account: account, name: 'Haircut', duration_minutes: 30, price: 50) }
  let(:new_service) { Service.create!(account: account, name: 'Color', duration_minutes: 60, price: 90) }
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

  it 'updates booking provider, services, and time' do
    new_time = 4.days.from_now.strftime('%Y-%m-%d %H:%M')

    tool.perform(
      tool_context,
      booking_id: booking.id,
      provider_id: new_provider.id,
      service_ids: new_service.id.to_s,
      datetime: new_time
    )

    booking.reload

    expect(booking.service_provider_id).to eq(new_provider.id)
    expect(booking.services.pluck(:id)).to eq([new_service.id])
    expect(booking.scheduled_at.to_i).to eq(DateTime.parse(new_time).to_i)
  end
end
