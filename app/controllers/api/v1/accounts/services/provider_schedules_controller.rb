# frozen_string_literal: true

class Api::V1::Accounts::Services::ProviderSchedulesController < Api::V1::Accounts::Services::BaseController
  before_action :fetch_provider
  before_action :fetch_schedule, only: %i[show update destroy]
  before_action :check_authorization

  def show
    render json: @schedule
  end

  def create
    @schedule = @provider.create_provider_schedule!(schedule_params)
    render json: @schedule, status: :created
  end

  def update
    @schedule.update!(schedule_params)
    render json: @schedule
  end

  def destroy
    @schedule.destroy!
    head :no_content
  end

  private

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
