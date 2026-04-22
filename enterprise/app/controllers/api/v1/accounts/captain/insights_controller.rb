class Api::V1::Accounts::Captain::InsightsController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action -> { check_authorization(Captain::Assistant) }

  def show
    service = Captain::InsightsService.new(
      account: Current.account,
      since: period_from,
      until_at: period_to,
      assistant_id: params[:assistant_id].presence
    )
    render json: service.call
  end

  private

  def period_from
    days = params[:days].presence&.to_i
    days = 30 if days.blank? || days <= 0 || days > 365
    days.days.ago.beginning_of_day
  end

  def period_to
    Time.current
  end
end
