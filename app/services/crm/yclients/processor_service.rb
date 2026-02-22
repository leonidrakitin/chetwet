class Crm::Yclients::ProcessorService < Crm::BaseProcessorService
  def self.crm_name
    'yclients'
  end

  def initialize(hook)
    super(hook)
    @partner_token = hook.settings['partner_token']
    @user_token = hook.settings['user_token']
    @company_id = hook.settings['company_id']
  end

  def handle_contact_created(contact)
    sync_contact(contact)
  end

  def handle_contact_updated(contact)
    contact.reload
    sync_contact(contact)
  end

  def handle_conversation_created(conversation)
    contact = conversation.contact
    yclients_id = ensure_yclients_client(contact)
    return if yclients_id.blank?

    record_data = build_record_data(conversation, yclients_id)
    result = records_client.create(record_data)
    return if result.blank?

    record_id = result.is_a?(Array) ? result.first&.dig('id') : result['id']
    return if record_id.blank?

    store_conversation_metadata(conversation, Crm::Yclients::Mappers::RecordMapper.map_to_metadata(result.is_a?(Array) ? result.first : result))
  rescue Crm::Yclients::Api::BaseClient::ApiError => e
    ChatwootExceptionTracker.new(e, account: @account).capture_exception
    Rails.logger.error "YClients API error creating record: #{e.message}"
  end

  def handle_conversation_resolved(conversation)
    record_id = conversation.additional_attributes.dig(crm_name, 'record_id')
    return if record_id.blank?

    records_client.update(record_id, { 'attendance' => 1 })
  rescue Crm::Yclients::Api::BaseClient::ApiError => e
    ChatwootExceptionTracker.new(e, account: @account).capture_exception
    Rails.logger.error "YClients API error updating record: #{e.message}"
  end

  private

  def sync_contact(contact)
    return unless identifiable_contact?(contact)

    client_id = get_external_id(contact)

    if client_id.present?
      clients_client.update(client_id, Crm::Yclients::Mappers::ContactMapper.map(contact))
    else
      new_id = find_or_create_client(contact)
      store_external_id(contact, new_id) if new_id.present?
    end
  rescue Crm::Yclients::Api::BaseClient::ApiError => e
    ChatwootExceptionTracker.new(e, account: @account).capture_exception
    Rails.logger.error "YClients API error syncing contact ##{contact.id}: #{e.message}"
  end

  def ensure_yclients_client(contact)
    client_id = get_external_id(contact)
    return client_id if client_id.present?

    return nil unless identifiable_contact?(contact)

    new_id = find_or_create_client(contact)
    store_external_id(contact, new_id) if new_id.present?
    new_id
  end

  def find_or_create_client(contact)
    existing = find_existing_client(contact)
    return existing['id'].to_s if existing.present?

    result = clients_client.create(Crm::Yclients::Mappers::ContactMapper.map(contact))
    result.is_a?(Array) ? result.first&.dig('id')&.to_s : result['id']&.to_s
  end

  def find_existing_client(contact)
    if contact.phone_number.present?
      found = clients_client.find_by_phone(contact.phone_number)
      return found if found.present?
    end

    if contact.email.present?
      found = clients_client.find_by_email(contact.email)
      return found if found.present?
    end

    nil
  end

  def build_record_data(conversation, yclients_id)
    {
      'staff_id' => 0,
      'services' => [],
      'client' => { 'id' => yclients_id },
      'comment' => "Chatwoot conversation ##{conversation.display_id}"
    }
  end

  def clients_client
    @clients_client ||= Crm::Yclients::Api::ClientsClient.new(@partner_token, @user_token, @company_id)
  end

  def records_client
    @records_client ||= Crm::Yclients::Api::RecordsClient.new(@partner_token, @user_token, @company_id)
  end
end
