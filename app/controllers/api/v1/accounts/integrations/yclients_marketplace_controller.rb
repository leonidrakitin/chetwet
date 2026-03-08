# frozen_string_literal: true

class Api::V1::Accounts::Integrations::YclientsMarketplaceController < Api::V1::Accounts::BaseController
  def connect
    salon_ids = normalized_salon_ids
    return render json: { error: I18n.t('errors.yclients_marketplace.invalid_salon_ids') }, status: :unprocessable_entity unless salon_ids

    Yclients::Marketplace::ConnectJob.perform_later(Current.account.id, salon_ids)
    render json: { status: 'accepted' }
  end

  def payment
    integration = find_integration!(payment_params[:salon_id])
    response = marketplace_notifications_service.notify_payment!(
      {
        salon_id: integration.salon_id,
        payment_sum: payment_params[:payment_sum],
        currency_iso: payment_params[:currency_iso],
        payment_date: payment_params[:payment_date],
        period_from: payment_params[:period_from],
        period_to: payment_params[:period_to]
      },
      application_id: payment_params[:application_id]
    )

    render json: response
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'YClients salon is not connected to this account' }, status: :not_found
  rescue Crm::Yclients::Marketplace::NotificationsService::NotificationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def refund
    find_integration!(refund_params[:salon_id])
    response = marketplace_notifications_service.refund_payment!(
      payment_id: params[:payment_id],
      application_id: refund_params[:application_id]
    )

    render json: response
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'YClients salon is not connected to this account' }, status: :not_found
  rescue Crm::Yclients::Marketplace::NotificationsService::NotificationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def normalized_salon_ids
    raw = connect_params[:salon_ids]
    return nil if raw.blank? || !raw.is_a?(Array)
    return nil if raw.any? { |id| !id.is_a?(Integer) && !id.to_s.match?(/\A\d+\z/) }

    ids = raw.map(&:to_i).uniq
    ids.presence
  end

  def connect_params
    params.permit(salon_ids: [])
  end

  def payment_params
    params.permit(:salon_id, :application_id, :payment_sum, :currency_iso, :payment_date, :period_from, :period_to)
  end

  def refund_params
    params.permit(:salon_id, :application_id)
  end

  def find_integration!(salon_id)
    Current.account.yclients_integrations.find_by!(salon_id: salon_id)
  end

  def marketplace_notifications_service
    @marketplace_notifications_service ||= Crm::Yclients::Marketplace::NotificationsService.new
  end
end
