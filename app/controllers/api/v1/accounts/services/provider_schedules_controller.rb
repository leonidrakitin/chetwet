# frozen_string_literal: true

class Api::V1::Accounts::Services::ProviderSchedulesController < Api::V1::Accounts::Services::BaseController
  before_action :fetch_provider
  before_action :fetch_schedule, only: %i[show update destroy]
  before_action :check_authorization

  def show
    render_schedule
  end

  def create
    @schedule = @provider.create_provider_schedule!(schedule_params)
    render_schedule(status: :created)
  end

  def update
    @schedule.update!(schedule_params)
    render_schedule
  end

  def destroy
    @schedule.destroy!
    head :no_content
  end

  private

  def render_schedule(status: :ok)
    render partial: 'api/v1/accounts/services/provider_schedule', formats: [:json], locals: { provider_schedule: @schedule }, status: status
  end

  def fetch_provider
    @provider = current_account.service_providers.find(params[:provider_id])
  end

  def fetch_schedule
    @schedule = @provider.provider_schedule
    raise ActiveRecord::RecordNotFound unless @schedule
  end

  def check_authorization
    authorize(@schedule || ProviderSchedule)
  end

  def schedule_params
    params.require(:provider_schedule).permit(
      :timezone, :inherit_account_schedule,
      working_hours: {},
      holidays: [:date, :name],
      breaks: [:start, :end]
    )
  end
end
