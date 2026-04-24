# frozen_string_literal: true

class Api::V1::Accounts::Captain::ApprovalRequestsController < Api::V1::Accounts::BaseController
  before_action :current_account

  def index
    @requests = Current.account.captain_approval_requests.order(created_at: :desc)
    @requests = @requests.where(conversation_id: params[:conversation_id]) if params[:conversation_id].present?
    @requests = @requests.where(status: params[:status]) if params[:status].present?
    @requests = @requests.page(params[:page] || 1).per(25)
    render json: @requests
  end

  def show
    @request = Current.account.captain_approval_requests.find(params[:id])
    render json: @request
  end

  def update
    @request = Current.account.captain_approval_requests.find(params[:id])

    if params[:selected_option_index].blank?
      render json: { error: 'selected_option_index is required' }, status: :unprocessable_entity
      return
    end

    # Idempotent: duplicate client submits (double-click, retry) after success should not 409.
    unless @request.pending?
      render json: @request.reload
      return
    end

    success = @request.resolve!(
      index: params[:selected_option_index].to_i,
      custom_text: params[:custom_response],
      by_user_id: Current.user.id
    )
    if success
      render json: @request.reload
    else
      render json: { error: 'Request already resolved' }, status: :conflict
    end
  end

  def generate_draft
    @request = Current.account.captain_approval_requests.find(params[:id])
    option_index = params[:selected_option_index].to_i

    result = ApprovalBot::DraftResponseService.new(@request, option_index).generate

    if result.present? && result[:message].present?
      render json: {
        draft: result[:message],
        option_index: option_index,
        follow_up_context: result[:follow_up_context]
      }
    else
      option = @request.options[option_index]&.with_indifferent_access
      render json: { draft: option&.dig(:label) || '', option_index: option_index }
    end
  end
end
