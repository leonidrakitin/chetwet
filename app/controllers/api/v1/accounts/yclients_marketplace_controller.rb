# frozen_string_literal: true

class Api::V1::Accounts::YclientsMarketplaceController < Api::V1::Accounts::BaseController
  def connect
    salon_ids = normalized_salon_ids
    return render json: { error: I18n.t('errors.yclients_marketplace.invalid_salon_ids') }, status: :unprocessable_entity unless salon_ids

    Yclients::Marketplace::ConnectJob.perform_later(Current.account.id, salon_ids)
    render json: { status: 'accepted' }
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
end
