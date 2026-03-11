# frozen_string_literal: true

class Crm::Yclients::Marketplace::NotificationsService
  include HTTParty

  BASE_URL = 'https://api.yclients.com/marketplace/partner'

  class NotificationError < StandardError
    attr_reader :code, :response

    def initialize(message = nil, code = nil, response = nil)
      @code = code
      @response = response
      super(message)
    end
  end

  def notify_payment!(payload, application_id: nil)
    payload = {
      salon_id: payload[:salon_id],
      application_id: resolved_application_id(application_id),
      payment_sum: payload[:payment_sum],
      currency_iso: payload[:currency_iso],
      payment_date: payload[:payment_date],
      period_from: payload[:period_from],
      period_to: payload[:period_to]
    }

    response = self.class.post(
      "#{BASE_URL}/payment",
      body: payload.to_json,
      headers: headers
    )

    parse_response!(response)
  end

  def refund_payment!(payment_id:, application_id: nil)
    response = self.class.post(
      "#{BASE_URL}/payment/refund/#{payment_id}",
      body: { application_id: resolved_application_id(application_id) }.to_json,
      headers: headers
    )

    parse_response!(response)
  end

  private

  def headers
    {
      'Content-Type' => 'application/json',
      'Accept' => 'application/vnd.yclients.v2+json',
      'Authorization' => "Bearer #{partner_token}"
    }
  end

  def partner_token
    token = InstallationConfig.find_by(name: 'YCLIENTS_MARKETPLACE_PARTNER_TOKEN')&.value
    raise NotificationError, 'YCLIENTS_MARKETPLACE_PARTNER_TOKEN is not configured' if token.blank?

    token
  end

  def resolved_application_id(application_id)
    value = application_id.presence || InstallationConfig.find_by(name: 'YCLIENTS_MARKETPLACE_APPLICATION_ID')&.value
    raise NotificationError, 'YCLIENTS_MARKETPLACE_APPLICATION_ID is not configured' if value.blank?

    value.to_i
  end

  def parse_response!(response)
    if response.success?
      parsed = response.parsed_response
      return parsed unless parsed.is_a?(Hash) && parsed['success'] == false

      raise NotificationError.new(
        parsed.dig('meta', 'message') || parsed['message'] || 'YClients marketplace notification failed',
        response.code,
        response
      )
    end

    raise NotificationError.new(
      "YClients marketplace notification failed: #{response.code} - #{response.body}",
      response.code,
      response
    )
  end
end
