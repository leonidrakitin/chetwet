# frozen_string_literal: true

class Booking::UpdateService
  def initialize(booking:, params:)
    @booking = booking
    @params = params || {}
  end

  def update
    validate!

    ActiveRecord::Base.transaction do
      update_booking
      update_booking_items if service_ids.present?
      @booking.calculate_total_duration if service_ids.present?
      Booking::ConflictChecker.new(@booking).check!
      @booking
    end
  end

  private

  def validate!
    raise ArgumentError, 'Booking is required' unless @booking
    raise ArgumentError, 'No updates provided' if updatable_params.empty? && service_ids.blank?
  end

  def update_booking
    updates = normalized_updates
    @booking.update!(updates) if updates.present?
  end

  def normalized_updates
    updates = passthrough_updates
    updates[:service_provider_id] = resolved_provider_id if updatable_params[:service_provider_id].present?
    updates[:scheduled_at] = DateTime.parse(updatable_params[:scheduled_at]) if updatable_params[:scheduled_at].present?
    updates[:total_duration_minutes] = updatable_params[:total_duration_minutes].to_i if updatable_params[:total_duration_minutes].present?
    updates
  end

  def passthrough_updates
    %i[customer_notes preferences internal_notes].each_with_object({}) do |key, acc|
      acc[key] = updatable_params[key] if updatable_params.key?(key)
    end
  end

  def resolved_provider_id
    @booking.account.service_providers.find(updatable_params[:service_provider_id]).id
  end

  def update_booking_items
    @booking.service_booking_items.destroy_all

    service_ids.each_with_index do |service_id, position|
      service = @booking.account.services.find(service_id)
      @booking.service_booking_items.create!(
        service: service,
        position: position,
        duration_minutes: service.duration_minutes,
        price: service.price
      )
    end
  end

  def updatable_params
    @updatable_params ||= @params.slice(
      :service_provider_id, :scheduled_at, :customer_notes, :preferences,
      :internal_notes, :total_duration_minutes
    )
  end

  def service_ids
    ids = @params[:service_ids]
    return [] if ids.blank?

    ids.is_a?(Array) ? ids : ids.split(',').map(&:strip).reject(&:blank?)
  end
end
