class Crm::Yclients::ProcessorService < Crm::BaseProcessorService
  def self.crm_name
    'yclients'
  end

  def initialize(hook)
    super(hook)
    @partner_token = hook.settings['partner_token']
    @user_token = Crm::Yclients::HookResolver.user_token_for(hook)
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
    sync_contact(conversation.contact)
  rescue Crm::Yclients::Api::BaseClient::ApiError => e
    ChatwootExceptionTracker.new(e, account: @account).capture_exception
    Rails.logger.error "YClients API error syncing contact on conversation create: #{e.message}"
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
      push_notes_as_comments(contact, client_id)
    else
      new_id = find_or_create_client(contact)
      store_external_id(contact, new_id) if new_id.present?
      push_notes_as_comments(contact, new_id) if new_id.present?
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
      found = lookup_client_by_phone(contact.phone_number)
      return found if found.present?
    end

    if contact.email.present?
      found = lookup_client_by_email(contact.email)
      return found if found.present?
    end

    nil
  end

  def get_external_id(contact)
    Crm::Yclients::ContactIdentity.external_id_for(contact, company_id: @company_id)
  end

  def store_external_id(contact, external_id)
    Crm::Yclients::ContactIdentity.store_external_id(contact, external_id, company_id: @company_id)
  end

  def clients_client
    @clients_client ||= Crm::Yclients::Api::ClientsClient.new(@partner_token, @user_token, @company_id)
  end

  def records_client
    @records_client ||= Crm::Yclients::Api::RecordsClient.new(@partner_token, @user_token, @company_id)
  end

  def comments_client
    @comments_client ||= Crm::Yclients::Api::CommentsClient.new(@partner_token, @user_token, @company_id)
  end

  def push_notes_as_comments(contact, yclients_id)
    existing_comments = comments_client.list(yclients_id)
    existing_texts = Array.wrap(existing_comments).to_set { |c| c['text'].to_s.strip }

    contact.notes.latest.limit(20).each do |note|
      text = note.content.strip
      next if text.blank?
      next if existing_texts.include?(text)

      comments_client.create(yclients_id, text)
    end
  rescue Crm::Yclients::Api::BaseClient::ApiError => e
    Rails.logger.warn "YClients ProcessorService: failed to push comments for contact #{contact.id}: #{e.message}"
  end

  def lookup_client_by_phone(phone_number)
    # rubocop:disable Rails/DynamicFindBy
    clients_client.find_by_phone(phone_number)
    # rubocop:enable Rails/DynamicFindBy
  end

  def lookup_client_by_email(email)
    # rubocop:disable Rails/DynamicFindBy
    clients_client.find_by_email(email)
    # rubocop:enable Rails/DynamicFindBy
  end
end
