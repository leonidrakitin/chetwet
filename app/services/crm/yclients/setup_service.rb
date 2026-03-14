class Crm::Yclients::SetupService
  def initialize(hook)
    @hook = hook
    @account = hook.account
  end

  def setup
    verify_api_access!
  rescue Crm::Yclients::Api::BaseClient::ApiError => e
    Rails.logger.error "YClients setup failed for hook ##{@hook.id}: #{e.message}"
    raise
  end

  private

  def clients_client
    @clients_client ||= Crm::Yclients::Api::ClientsClient.new(
      @hook.settings['partner_token'],
      Crm::Yclients::HookResolver.user_token_for(@hook),
      @hook.settings['company_id']
    )
  end

  def verify_api_access!
    clients_client.search(phone: '+70000000000')
    Rails.logger.info "YClients API access verified for hook ##{@hook.id}"
  rescue Crm::Yclients::Api::BaseClient::ApiError => e
    raise unless e.code == 404

    Rails.logger.info "YClients API access verified for hook ##{@hook.id}"
  end
end
