# frozen_string_literal: true

class Api::V1::Accounts::Services::BookingsController < Api::V1::Accounts::Services::BaseController
  before_action :fetch_booking, only: %i[show update destroy confirm cancel]
  before_action :check_authorization

  def index
    @bookings = current_account.service_bookings.includes(:contact, :service_provider, :services)
    @bookings = filter_bookings(@bookings)
    render json: @bookings
  end

  def show
    render json: @booking
  end

  def create
    @booking = Booking::BookingService.new(
      account: current_account,
      params: booking_params
    ).book

    render json: @booking, status: :created
  rescue Booking::ConflictChecker::ConflictError => e
    render json: { error: e.message }, status: :conflict
  end

  def update
    @booking.update!(update_params)
    render json: @booking
  end

  def destroy
    @booking.destroy!
    head :no_content
  end

  def available_slots
    slots = Booking::AvailabilityService.new(
      account: current_account,
      provider_id: params[:provider_id],
      service_ids: params[:service_ids],
      date: params[:date]
    ).call

    render json: { slots: slots }
  rescue Date::Error => e
    render json: { error: "Invalid date format: #{e.message}" }, status: :bad_request
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end

  def upcoming
    @bookings = current_account.service_bookings
                               .upcoming
                               .includes(:contact, :service_provider, :services)
    render json: @bookings
  end

  def confirm
    @booking.confirm!
    render json: @booking
  end

  def cancel
    @booking.cancel!(reason: params[:reason])
    render json: @booking
  end

  private

  def fetch_booking
    @booking = current_account.service_bookings.find(params[:id])
  end

  def check_authorization
    authorize(@booking || ServiceBooking)
  end

  def booking_params
    params.require(:booking).permit(
      :contact_id, :service_provider_id, :scheduled_at,
      :customer_notes, :internal_notes,
      preferences: {},
      service_booking_items_attributes: %i[service_id position _destroy]
    )
  end

  def update_params
    params.require(:booking).permit(
      :scheduled_at, :customer_notes, :internal_notes,
      :status, preferences: {}
    )
  end

  def filter_bookings(bookings)
    bookings = bookings.for_provider(params[:provider_id]) if params[:provider_id].present?
    bookings = bookings.for_contact(params[:contact_id]) if params[:contact_id].present?
    bookings = bookings.on_date(params[:date]) if params[:date].present?
    bookings = bookings.where(status: params[:status]) if params[:status].present?
    bookings.order(:scheduled_at)
  end
end
