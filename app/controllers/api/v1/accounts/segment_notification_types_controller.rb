class Api::V1::Accounts::SegmentNotificationTypesController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_notification_type, only: [:show, :update, :destroy]

  def index
    @notification_types = Current.account.segment_notification_types.ordered
  end

  def show; end

  def create
    @notification_type = Current.account.segment_notification_types.create!(permitted_params)
  end

  def update
    @notification_type.update!(permitted_params)
  end

  def destroy
    @notification_type.destroy!
    head :no_content
  end

  private

  def fetch_notification_type
    @notification_type = Current.account.segment_notification_types.find(params[:id])
  end

  def permitted_params
    params.require(:segment_notification_type).permit(:name, :icon, :active, :position)
  end
end
