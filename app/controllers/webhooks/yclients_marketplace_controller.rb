# frozen_string_literal: true

# Inherits from ActionController::API (no CSRF). Do not add skip_before_action :verify_authenticity_token
# or Rails will raise "callback :verify_authenticity_token has not been defined".
class Webhooks::YclientsMarketplaceController < ActionController::API
  def process
    Rails.logger.info "YClients Marketplace webhook: raw body=#{request.raw_post.truncate(500)}"

    payload = parse_payload
    unless payload.is_a?(Hash)
      Rails.logger.warn 'YClients Marketplace webhook: invalid or empty JSON'
      return head :unprocessable_entity
    end

    return head :unauthorized if webhook_secret_configured? && !verify_webhook_secret!

    handle_event(payload)
    head :ok
  rescue StandardError => e
    Rails.logger.error "YClients Marketplace webhook error: #{e.message}"
    head :ok
  end

  private

  def handle_event(payload)
    event = payload['event'] || payload[:event]
    salon_id = (payload['salon_id'] || payload[:salon_id])&.to_i

    case event.to_s
    when 'integration_revoked', 'integration_disabled'
      revoke_integrations(salon_id)
    when 'integration_activated'
      update_bearer_token(salon_id, payload)
    else
      Rails.logger.info "YClients Marketplace webhook: unhandled event=#{event}"
    end
  end

  def parse_payload
    return {} if request.raw_post.blank?

    JSON.parse(request.raw_post).with_indifferent_access
  rescue JSON::ParserError
    nil
  end

  def webhook_secret_configured?
    InstallationConfig.find_by(name: 'YCLIENTS_MARKETPLACE_WEBHOOK_SECRET')&.value.present?
  end

  def verify_webhook_secret!
    secret = InstallationConfig.find_by(name: 'YCLIENTS_MARKETPLACE_WEBHOOK_SECRET')&.value
    return true if secret.blank?

    signature = request.headers['X-Yclients-Signature'] || request.headers['X-Webhook-Signature']
    return false if signature.blank?
    return true if ActiveSupport::SecurityUtils.secure_compare(signature, secret)

    Rails.logger.warn 'YClients Marketplace webhook: signature mismatch'
    false
  end

  def revoke_integrations(salon_id)
    if salon_id.blank?
      Rails.logger.warn 'YClients Marketplace webhook: integration_revoked without salon_id'
      return
    end

    YclientsIntegration.where(salon_id: salon_id).active.find_each do |integration|
      integration.update!(status: :revoked)
    end
    Rails.logger.info "YClients Marketplace webhook: revoked integrations for salon_id=#{salon_id}"
  end

  def update_bearer_token(salon_id, payload)
    return if salon_id.blank?

    token = payload['bearer_token'] || payload['token'] || payload.dig('data', 'bearer_token') || payload.dig('data', 'token')
    return if token.blank?

    YclientsIntegration.where(salon_id: salon_id).find_each do |integration|
      integration.update!(bearer_token: token)
      update_hook_user_token(integration)
      Rails.logger.info "YClients Marketplace webhook: updated bearer_token for integration id=#{integration.id}"
    end
  end

  def update_hook_user_token(integration)
    hook = integration.account.hooks
                      .where(app_id: 'yclients')
                      .where("(settings->>'company_id') = ?", integration.salon_id.to_s)
                      .first
    return if hook.blank?

    hook.settings = (hook.settings || {}).merge('user_token' => integration.bearer_token.to_s)
    hook.save!
  end
end
