# frozen_string_literal: true

class Api::V1::Accounts::Services::ServicesController < Api::V1::Accounts::Services::BaseController
  before_action :fetch_service, only: %i[show update destroy]
  before_action :check_authorization

  def index
    @services = current_account.services.ordered
    @services = @services.active if params[:active_only]
    render json: @services
  end

  def show
    render json: @service
  end

  def create
    @service = current_account.services.create!(service_params)
    render json: @service, status: :created
  end

  def update
    @service.update!(service_params)
    render json: @service
  end

  def destroy
    @service.destroy!
    head :no_content
  end

  private

  def fetch_service
    @service = current_account.services.find(params[:id])
  end

  def check_authorization
    authorize(@service || Service)
  end

  def service_params
    params.require(:service).permit(
      :name, :description, :duration_minutes, :price, :currency, :active,
      metadata: {}
    )
  end
end
