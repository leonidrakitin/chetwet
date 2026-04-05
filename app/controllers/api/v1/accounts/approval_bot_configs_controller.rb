# frozen_string_literal: true

class Api::V1::Accounts::ApprovalBotConfigsController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action :check_admin_authorization
  before_action :set_config, only: [:update, :destroy]

  def index
    render json: Current.account.approval_bot_configs
  end

  def create
    @config = Current.account.approval_bot_configs.create!(config_params)
    render json: @config, status: :created
  end

  def update
    @config.update!(config_params)
    render json: @config
  end

  def destroy
    @config.destroy!
    head :no_content
  end

  private

  def set_config
    @config = Current.account.approval_bot_configs.find_by!(channel_type: params[:channel_type])
  end

  def config_params
    params.require(:approval_bot_config).permit(:channel_type, :bot_token, :bot_name, :enabled)
  end

  def check_admin_authorization
    raise Pundit::NotAuthorizedError unless Current.user&.administrator?
  end
end
