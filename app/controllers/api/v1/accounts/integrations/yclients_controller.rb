class Api::V1::Accounts::Integrations::YclientsController < Api::V1::Accounts::BaseController
  before_action :fetch_hooks
  before_action :fetch_contact, only: [:records, :finances]

  def records
    render json: { records: aggregated_records }
  rescue Crm::Yclients::Api::BaseClient::ApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def finances
    transactions = aggregated_records.flat_map do |record|
      Crm::Yclients::Mappers::RecordMapper.extract_transactions([record]).map do |transaction|
        transaction.merge('company_id' => record['company_id'])
      end
    end

    render json: { transactions: transactions }
  rescue Crm::Yclients::Api::BaseClient::ApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def widget_snippet
    inbox = Current.account.inboxes.where(channel_type: 'Channel::WebWidget').first
    return render json: { error: 'No web widget inbox found' }, status: :not_found if inbox.blank?
    return render json: { error: widget_snippet_error_message }, status: :unprocessable_entity if widget_hook.blank?

    snippet = build_widget_snippet(inbox)
    render json: { snippet: snippet }
  end

  def sync_contacts
    @hooks.find_each do |hook|
      Yclients::ContactsSyncJob.perform_later(Current.account.id, hook.id)
    end

    render json: { status: 'accepted', hooks_count: @hooks.size }
  end

  private

  def fetch_hooks
    @hooks = Crm::Yclients::HookResolver.hooks_for(Current.account, company_id: params[:company_id])
    return if @hooks.exists?

    render json: { error: 'YClients integration not configured' }, status: :not_found
  end

  def fetch_contact
    @contact = Current.account.contacts.find_by(id: params[:contact_id])
    render json: { error: 'Contact not found' }, status: :not_found if @contact.blank?
  end

  def aggregated_records
    @aggregated_records ||= begin
      records = @hooks.flat_map { |hook| records_for_hook(hook) }
      records.sort_by { |record| record['datetime'] || record['date'] || '' }.reverse
    end
  end

  def records_client_for(hook)
    Crm::Yclients::Api::RecordsClient.new(
      hook.settings['partner_token'],
      Crm::Yclients::HookResolver.user_token_for(hook),
      hook.settings['company_id']
    )
  end

  def widget_hook
    @widget_hook ||= Crm::Yclients::HookResolver.single_hook_for(Current.account, company_id: params[:company_id])
  end

  def widget_snippet_error_message
    'Unable to build a snippet without a single YClients company selection. Pass company_id to this endpoint when multiple salons are connected.'
  end

  # rubocop:disable Metrics/MethodLength
  def build_widget_snippet(inbox)
    webhook_url = "#{ENV.fetch('FRONTEND_URL', '')}/webhooks/yclients?token=#{widget_hook.access_token}"

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
  # rubocop:enable Metrics/MethodLength

  def records_for_hook(hook)
    company_id = Crm::Yclients::HookResolver.company_id_for(hook)
    yclients_id = Crm::Yclients::ContactIdentity.external_id_for(@contact, company_id: company_id)
    return [] if yclients_id.blank?

    records_client_for(hook).get_by_client(yclients_id).map do |record|
      record.merge('company_id' => company_id)
    end
  end
end
