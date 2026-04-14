# frozen_string_literal: true

class Api::V1::Accounts::Services::ScheduleController < Api::V1::Accounts::Services::BaseController
  before_action :fetch_schedule, only: %i[show update]
  before_action :check_authorization

  def show
    render_schedule
  end

  def create
    @schedule = current_account.create_service_schedule!(schedule_params)
    render_schedule(status: :created)
  end

  def update
    @schedule.update!(schedule_params)
    render_schedule
  end

  private

  def render_schedule(status: :ok)
    return render(json: nil, status: status) if @schedule.nil?

    render partial: 'api/v1/accounts/services/schedule', formats: [:json], locals: { schedule: @schedule }, status: status
  end

  def fetch_schedule
    @schedule = current_account.service_schedule
  end

  def check_authorization
    authorize(@schedule || ServiceSchedule)
  end

  def schedule_params
    params.require(:schedule).permit(
      :timezone, :slot_interval_minutes,
      working_hours: {},
      holidays: [:date, :name],
      breaks: [:start, :end]
    )
  end
end
