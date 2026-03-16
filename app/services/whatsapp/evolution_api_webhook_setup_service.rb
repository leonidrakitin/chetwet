class Whatsapp::EvolutionApiWebhookSetupService
  def initialize(channel)
    @channel = channel
  end

  def perform
    create_instance
    configure_webhook
  end

  private

  def create_instance
    HTTParty.post(
      "#{api_url}/instance/create",
      headers: api_headers,
      body: {
        instanceName: instance_name,
        integration: 'WHATSAPP-BAILEYS',
        qrcode: true
      }.to_json
    )
  end

  def configure_webhook
    callback_url = "#{ENV.fetch('FRONTEND_URL', nil)}/webhooks/evolution_api/#{@channel.phone_number}"

    HTTParty.post(
      "#{api_url}/webhook/set/#{instance_name}",
      headers: api_headers,
      body: {
        webhook: {
          url: callback_url,
          webhook_by_events: false,
          enabled: true,
          events: %w[MESSAGES_UPSERT MESSAGES_UPDATE CONNECTION_UPDATE]
        }
      }.to_json
    )
  end

  def api_url
    @channel.provider_config['api_url']
  end

  def instance_name
    @channel.provider_config['instance_name']
  end

  def api_headers
    { 'apikey' => @channel.provider_config['api_key'], 'Content-Type' => 'application/json' }
  end
end
