# frozen_string_literal: true

class Api::V1::Accounts::Services::ProvidersController < Api::V1::Accounts::Services::BaseController
  before_action :fetch_provider, only: %i[show update destroy]
  before_action :check_authorization

  def index
    @providers = current_account.service_providers.ordered
    @providers = @providers.active if params[:active_only]
    render json: @providers
  end

  def show
    render json: @provider
  end

  def create
    @provider = current_account.service_providers.create!(provider_params)
    render json: @provider, status: :created
  end

  def update
    @provider.update!(provider_params)
    render json: @provider
  end

  def destroy
    @provider.destroy!
    head :no_content
  end

  private

  def fetch_provider
    @provider = current_account.service_providers.find(params[:id])
  end

  def check_authorization
    authorize(@provider || ServiceProvider)
  end

  def provider_params
    params.require(:provider).permit(:name, :description, :active, metadata: {})
  end
end
