# frozen_string_literal: true

class Crm::Yclients::Marketplace::CallbackService
  DEFAULT_CALLBACK_URL = 'https://api.yclients.com/marketplace/partner/callback'

  class CallbackError < StandardError
    attr_reader :code, :response

    def initialize(message = nil, code = nil, response = nil)
      @code = code
      @response = response
      super(message)
    end
  end

  def initialize(account_id:, salon_ids:, inbox_ids_by_salon: {})
    @account_id = account_id
    @salon_ids = Array(salon_ids).map(&:to_i).uniq
    @inbox_ids_by_salon = inbox_ids_by_salon.transform_keys(&:to_i)
  end

  def call
    partner_token = InstallationConfig.find_by(name: 'YCLIENTS_MARKETPLACE_PARTNER_TOKEN')&.value
    system_user_id = InstallationConfig.find_by(name: 'YCLIENTS_SYSTEM_USER_ID')&.value

    raise ArgumentError, 'YCLIENTS_MARKETPLACE_PARTNER_TOKEN is not configured' if partner_token.blank?
    raise ArgumentError, 'YCLIENTS_SYSTEM_USER_ID is not configured' if system_user_id.blank?

    account = Account.find(@account_id)
    results = { success: [], errors: [] }

    @salon_ids.each do |salon_id|
      activate_salon(account, salon_id, partner_token, system_user_id, results)
    end

    results
  end

  private

  def activate_salon(account, salon_id, partner_token, system_user_id, results)
    post_callback_with_settings(salon_id, system_user_id, partner_token)
    integration = save_integration(account, salon_id, nil, system_user_id)
    ensure_hook_for_integration(account, integration, partner_token)
    Rails.logger.info "YClients Marketplace: activated salon_id=#{salon_id} for account_id=#{account.id}"
    results[:success] << salon_id
  rescue CallbackError, Crm::Yclients::Api::BaseClient::ApiError => e
    Rails.logger.error "YClients Marketplace: callback failed for salon_id=#{salon_id}: #{e.message}"
    results[:errors] << { salon_id: salon_id, message: e.message }
  rescue StandardError => e
    Rails.logger.error "YClients Marketplace: error for salon_id=#{salon_id}: #{e.message}"
    results[:errors] << { salon_id: salon_id, message: e.message }
  end

  def save_integration(account, salon_id, bearer_token, system_user_id)
    integration = YclientsIntegration.find_or_initialize_by(account_id: account.id, salon_id: salon_id)
    inbox_id = resolved_inbox_id_for(account, salon_id)
    integration.assign_attributes(
      bearer_token: bearer_token.presence || integration.bearer_token,
      connected_at: Time.current,
      status: :active,
      system_user_id: system_user_id,
      inbox_id: inbox_id
    )
    integration.save!
    integration
  end

  def callback_url
    InstallationConfig.find_by(name: 'YCLIENTS_MARKETPLACE_CALLBACK_URL')&.value.presence || DEFAULT_CALLBACK_URL
  end

  def marketplace_application_id
    value = InstallationConfig.find_by(name: 'YCLIENTS_MARKETPLACE_APPLICATION_ID')&.value
    raise ArgumentError, 'YCLIENTS_MARKETPLACE_APPLICATION_ID is not configured' if value.blank?

    value.to_i
  end

  def post_callback_with_settings(salon_id, system_user_id, partner_token)
    body = { salon_id: salon_id, application_id: marketplace_application_id, settings: { user_id: system_user_id.to_s } }
    response = HTTParty.post(
      callback_url,
      body: body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Accept' => 'application/vnd.yclients.v2+json',
        'Authorization' => "Bearer #{partner_token}"
      }
    )
    check_callback_response!(response, salon_id)
    parsed = response.parsed_response
    check_callback_parsed!(response, parsed)
    Rails.logger.info "YClients Marketplace: callback_with_settings success for salon_id=#{salon_id}"
  end

  def check_callback_response!(response, _salon_id)
    return if response.success?

    raise CallbackError.new(
      "YClients callback failed: #{response.code} - #{response.body}",
      response.code,
      response
    )
  end

  def check_callback_parsed!(response, parsed)
    return unless parsed.is_a?(Hash) && parsed['success'] == false

    raise CallbackError.new(
      parsed['meta']&.dig('message') || parsed['message'] || 'Callback rejected',
      response.code,
      response
    )
  end

  def ensure_hook_for_integration(account, integration, partner_token)
    hook = account.hooks
                  .where(app_id: 'yclients')
                  .where("(settings->>'company_id') = ?", integration.salon_id.to_s)
                  .first_or_initialize

    hook.inbox_id = integration.inbox_id
    hook.settings = (hook.settings || {}).merge(
      'company_id' => integration.salon_id.to_s,
      'user_token' => integration.bearer_token.to_s,
      'partner_token' => partner_token
    )
    hook.status = :enabled
    hook.save!
  end

  def resolved_inbox_id_for(account, salon_id)
    configured_inbox_id = @inbox_ids_by_salon[salon_id]
    return configured_inbox_id if configured_inbox_id.present?

    existing_integration = account.yclients_integrations.find_by(salon_id: salon_id)
    return existing_integration.inbox_id if existing_integration&.inbox_id.present?

    account.inboxes.find_by(channel_type: 'Channel::WebWidget')&.id
  end
end
