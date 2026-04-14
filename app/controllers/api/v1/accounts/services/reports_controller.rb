# frozen_string_literal: true

class Api::V1::Accounts::Services::ReportsController < Api::V1::Accounts::Services::BaseController
  before_action :check_authorization

  DAYS_OF_WEEK = %w[sunday monday tuesday wednesday thursday friday saturday].freeze

  def index
    start_date = params[:start_date]&.to_date || 30.days.ago.to_date
    end_date = params[:end_date]&.to_date || Date.current

    render json: {
      provider_utilization: provider_utilization(start_date, end_date),
      peak_hours: peak_hours(start_date, end_date),
      service_popularity: service_popularity(start_date, end_date),
      booking_stats: booking_stats(start_date, end_date)
    }
  end

  private

  def provider_utilization(start_date, end_date)
    current_account.service_providers.active.map do |provider|
      bookings = provider.service_bookings
                         .where(scheduled_at: start_date.beginning_of_day..end_date.end_of_day)
                         .active_bookings

      total_minutes = bookings.sum(:total_duration_minutes)
      schedule = provider.effective_schedule

      working_minutes = calculate_working_minutes(schedule, start_date, end_date)

      {
        id: provider.id,
        name: provider.name,
        total_bookings: bookings.count,
        total_minutes: total_minutes,
        utilization_rate: working_minutes.positive? ? (total_minutes.to_f / working_minutes * 100).round(1) : 0
      }
    end
  end

  def peak_hours(start_date, end_date)
    hour_counts = current_account.service_bookings
                                 .where(scheduled_at: start_date.beginning_of_day..end_date.end_of_day)
                                 .active_bookings
                                 .group('EXTRACT(HOUR FROM scheduled_at)')
                                 .count
                                 .transform_keys(&:to_i)

    (6..22).map do |hour|
      {
        hour: hour,
        label: format('%02d:00', hour),
        count: hour_counts[hour] || 0
      }
    end
  end

  def service_popularity(start_date, end_date)
    booking_items = service_popularity_scope(start_date, end_date)
    counts_by_service = booking_items.group(:service_id).count
    revenue_by_service = booking_items.group(:service_id).sum(:price)

    entries = current_account.services.active.map do |service|
      service_popularity_entry(service, counts_by_service, revenue_by_service)
    end
    entries.sort_by { |s| -s[:booking_count] }
  end

  def service_popularity_scope(start_date, end_date)
    range = start_date.beginning_of_day..end_date.end_of_day
    ServiceBookingItem
      .joins(:service_booking)
      .where(service_bookings: { scheduled_at: range, account_id: current_account.id })
      .where.not(service_bookings: { status: 'cancelled' })
  end

  def service_popularity_entry(service, counts_by_service, revenue_by_service)
    {
      id: service.id,
      name: service.name,
      duration_minutes: service.duration_minutes,
      price: service.price,
      booking_count: counts_by_service[service.id] || 0,
      revenue: revenue_by_service[service.id] || 0
    }
  end

  def booking_stats(start_date, end_date)
    bookings = current_account.service_bookings
                              .where(scheduled_at: start_date.beginning_of_day..end_date.end_of_day)

    {
      total: bookings.count,
      pending: bookings.where(status: 'pending').count,
      confirmed: bookings.where(status: 'confirmed').count,
      completed: bookings.where(status: 'completed').count,
      cancelled: bookings.where(status: 'cancelled').count,
      by_day: bookings_by_day(bookings, start_date, end_date)
    }
  end

  def bookings_by_day(bookings, start_date, end_date)
    (start_date..end_date).map do |date|
      {
        date: date.to_s,
        count: bookings.where(scheduled_at: date.all_day).count
      }
    end
  end

  def calculate_working_minutes(schedule, start_date, end_date)
    return 0 unless schedule

    total_minutes = 0
    (start_date..end_date).each do |date|
      total_minutes += calculate_day_working_minutes(schedule, date)
    end

    total_minutes
  end

  def calculate_day_working_minutes(schedule, date)
    return 0 if schedule.holiday?(date)

    day_name = DAYS_OF_WEEK[date.wday]
    day_config = schedule.working_hours[day_name]

    return 0 unless day_config&.dig('enabled')

    day_config['slots'].sum do |slot|
      calculate_slot_minutes(slot)
    end
  end

  def calculate_slot_minutes(slot)
    start_hour, start_min = slot['start'].split(':').map(&:to_i)
    end_hour, end_min = slot['end'].split(':').map(&:to_i)
    ((end_hour * 60) + end_min) - ((start_hour * 60) + start_min)
  end

  def check_authorization
    authorize(:report, policy_class: ServiceSchedulePolicy)
  end
end
