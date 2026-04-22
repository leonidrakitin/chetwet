# frozen_string_literal: true

class Booking::BookingService
  def initialize(account:, params:, contact: nil)
    @account = account
    @params = params
    @contact = contact || find_contact
  end

  def book
    validate!

    ActiveRecord::Base.transaction do
      create_booking
      create_booking_items
      calculate_total_duration
      check_conflicts
      @booking
    end
  end

  def cancel(reason: nil)
    raise ActiveRecord::RecordNotFound unless @booking

    @booking.cancel!(reason: reason)
    @booking
  end

  private

  def find_contact
    return nil unless @params[:contact_id]

    @account.contacts.find(@params[:contact_id])
  end

  def validate!
    raise ArgumentError, 'Contact is required' unless @contact
    raise ArgumentError, 'Service provider is required' unless @params[:service_provider_id]
    raise ArgumentError, 'Scheduled time is required' unless @params[:scheduled_at]
    raise ArgumentError, 'At least one service is required' if service_ids.empty?
  end

  def create_booking
    @booking = @account.service_bookings.create!(
      contact: @contact,
      service_provider_id: @params[:service_provider_id],
      scheduled_at: parse_scheduled_at,
      customer_notes: @params[:customer_notes],
      internal_notes: @params[:internal_notes],
      preferences: @params[:preferences] || {},
      status: :confirmed
    )
  end

  def create_booking_items
    service_ids.each_with_index do |service_id, position|
      service = @account.services.find(service_id)
      @booking.service_booking_items.create!(
        service: service,
        position: position,
        duration_minutes: service.duration_minutes,
        price: service.price
      )
    end
  end

  def calculate_total_duration
    @booking.calculate_total_duration
  end

  def check_conflicts
    Booking::ConflictChecker.new(@booking).check!
  end

  def service_ids
    items = @params[:service_booking_items_attributes] || []
    items.filter_map { |item| item[:service_id] || item['service_id'] }
  end

  def parse_scheduled_at
    scheduled = @params[:scheduled_at]
    return scheduled if scheduled.is_a?(Time) || scheduled.is_a?(ActiveSupport::TimeWithZone)

    Time.zone.parse(scheduled.to_s)
  end
end
