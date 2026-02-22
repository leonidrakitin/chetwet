class Api::V1::Accounts::Integrations::YclientsController < Api::V1::Accounts::BaseController
  before_action :fetch_hook
  before_action :fetch_contact, only: [:records, :finances]

  def records
    yclients_id = @contact.additional_attributes.dig('external', 'yclients_id')
    return render json: { records: [] } if yclients_id.blank?

    data = records_client.get_by_client(yclients_id)
    render json: { records: data }
  rescue Crm::Yclients::Api::BaseClient::ApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def finances
    yclients_id = @contact.additional_attributes.dig('external', 'yclients_id')
    return render json: { transactions: [] } if yclients_id.blank?

    data = records_client.get_by_client(yclients_id)
    transactions = Crm::Yclients::Mappers::RecordMapper.extract_transactions(data)
    render json: { transactions: transactions }
  rescue Crm::Yclients::Api::BaseClient::ApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def widget_snippet
    inbox = Current.account.inboxes.where(channel_type: 'Channel::WebWidget').first
    return render json: { error: 'No web widget inbox found' }, status: :not_found if inbox.blank?

    snippet = build_widget_snippet(inbox)
    render json: { snippet: snippet }
  end

  private

  def fetch_hook
    @hook = Integrations::Hook.find_by!(account: Current.account, app_id: 'yclients')
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'YClients integration not configured' }, status: :not_found
  end

  def fetch_contact
    @contact = Current.account.contacts.find_by(id: params[:contact_id])
    render json: { error: 'Contact not found' }, status: :not_found if @contact.blank?
  end

  def records_client
    @records_client ||= Crm::Yclients::Api::RecordsClient.new(
      @hook.settings['partner_token'],
      @hook.settings['user_token'],
      @hook.settings['company_id']
    )
  end

  def build_widget_snippet(inbox)
    webhook_url = "#{ENV.fetch('FRONTEND_URL', '')}/webhooks/yclients?token=#{@hook.access_token}"

    <<~JS
      <!-- Chatwoot Widget -->
      <script>
        (function(d,t) {
          var BASE_URL="#{ENV.fetch('FRONTEND_URL', '')}";
          var g=d.createElement(t),s=d.getElementsByTagName(t)[0];
          g.src=BASE_URL+"/packs/js/sdk.js";
          g.defer = true;
          g.async = true;
          s.parentNode.insertBefore(g,s);
          g.onload=function(){
            window.chatwootSDK.run({
              websiteToken: '#{inbox.channel.website_token}',
              baseUrl: BASE_URL
            })
          }
        })(document,"script");
      </script>
      <!-- YClients Webhook URL (configure in YClients): #{webhook_url} -->
    JS
  end
end
