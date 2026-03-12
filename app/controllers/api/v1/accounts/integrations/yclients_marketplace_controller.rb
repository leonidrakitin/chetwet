# frozen_string_literal: true

class Api::V1::Accounts::Integrations::YclientsMarketplaceController < Api::V1::Accounts::BaseController
  def status
    salon_ids = normalized_salon_ids
    return render json: { error: I18n.t('errors.yclients_marketplace.invalid_salon_ids') }, status: :unprocessable_entity unless salon_ids

    connected_salon_ids = connected_salon_ids_for(salon_ids)

    render json: {
      status: connected_salon_ids.sort == salon_ids.sort ? 'already_connected' : 'not_connected',
      connected_salon_ids: connected_salon_ids,
      integrations: integrations_payload(salon_ids)
    }
  end

  # rubocop:disable Metrics/MethodLength
  def connect
    salon_ids = normalized_salon_ids
    return render json: { error: I18n.t('errors.yclients_marketplace.invalid_salon_ids') }, status: :unprocessable_entity unless salon_ids

    connected_salon_ids = connected_salon_ids_for(salon_ids)
    remaining_salon_ids = salon_ids - connected_salon_ids

    if remaining_salon_ids.empty?
      return render json: {
        status: 'already_connected',
        connected_salon_ids: connected_salon_ids,
        integrations: integrations_payload(salon_ids)
      }
    end

    results = Crm::Yclients::Marketplace::CallbackService.new(
      account_id: Current.account.id,
      salon_ids: remaining_salon_ids,
      inbox_ids_by_salon: inbox_ids_by_salon
    ).call

    refreshed_connected_salon_ids = connected_salon_ids_for(salon_ids)
    if results[:errors].blank?
      return render json: {
        status: 'connected',
        connected_salon_ids: refreshed_connected_salon_ids,
        integrations: integrations_payload(salon_ids)
      }
    end

    render json: {
      status: 'error',
      connected_salon_ids: refreshed_connected_salon_ids,
      integrations: integrations_payload(salon_ids),
      errors: results[:errors],
      error: results[:errors].pluck(:message).uniq.join(', ')
    }, status: :unprocessable_entity
  end
  # rubocop:enable Metrics/MethodLength

  def update_binding
    integration = find_integration!(binding_params[:salon_id])
    integration.update!(inbox_id: binding_params[:inbox_id])
    update_hook_inbox!(integration)

    render json: {
      status: 'updated',
      integration: integration_payload(integration)
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'YClients salon is not connected to this account' }, status: :not_found
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
    params.permit(salon_ids: [], inbox_ids_by_salon: {})
  end

  def payment_params
    params.permit(:salon_id, :application_id, :payment_sum, :currency_iso, :payment_date, :period_from, :period_to)
  end

  def refund_params
    params.permit(:salon_id, :application_id)
  end

  def binding_params
    params.permit(:salon_id, :inbox_id)
  end

  def find_integration!(salon_id)
    Current.account.yclients_integrations.find_by!(salon_id: salon_id)
  end

  def marketplace_notifications_service
    @marketplace_notifications_service ||= Crm::Yclients::Marketplace::NotificationsService.new
  end

  def connected_salon_ids_for(salon_ids)
    Current.account.hooks
           .where(app_id: 'yclients')
           .where("settings->>'company_id' IN (?)", salon_ids.map(&:to_s))
           .pluck(Arel.sql("settings->>'company_id'"))
           .map(&:to_i)
           .uniq
  end

  def inbox_ids_by_salon
    connect_params[:inbox_ids_by_salon] || {}
  end

  def integrations_payload(salon_ids)
    Current.account.yclients_integrations.where(salon_id: salon_ids).order(:salon_id).map do |integration|
      integration_payload(integration)
    end
  end

  def integration_payload(integration)
    {
      id: integration.id,
      salon_id: integration.salon_id,
      inbox_id: integration.inbox_id,
      status: integration.status
    }
  end

  def update_hook_inbox!(integration)
    hook = Current.account.hooks
                  .where(app_id: 'yclients')
                  .where("(settings->>'company_id') = ?", integration.salon_id.to_s)
                  .first
    return if hook.blank?

    hook.update!(inbox_id: integration.inbox_id)
  end
end
