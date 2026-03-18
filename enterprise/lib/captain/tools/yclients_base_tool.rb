# frozen_string_literal: true

class Captain::Tools::YclientsBaseTool < Captain::Tools::BasePublicTool
  def active?
    Crm::Yclients::HookResolver.hooks_for(assistant_account).exists?
  end

  private

  def yclients_hook(state: nil, company_id: nil)
    conversation_company_id = state&.dig(:conversation, :additional_attributes, 'yclients', 'company_id') ||
                              state&.dig(:conversation, :additional_attributes, :yclients, :company_id)
    contact = find_contact(state) if state.present?
    inferred_company_id = if company_id.present?
                            company_id
                          elsif conversation_company_id.present?
                            conversation_company_id
                          elsif contact.present?
                            inferred_company_id_for_contact(contact)
                          end

    Crm::Yclients::HookResolver.single_hook_for(assistant_account, company_id: inferred_company_id)
  end

  def inferred_company_id_for_contact(contact)
    company_ids = Crm::Yclients::ContactIdentity.company_ids(contact)
    company_ids.first if company_ids.one?
  end

  def missing_hook_message
    'YClients hook is ambiguous or not configured. Provide company_id when multiple salons are connected.'
  end

  def clients_client_for(hook)
    Crm::Yclients::Api::ClientsClient.new(
      hook.settings['partner_token'],
      Crm::Yclients::HookResolver.user_token_for(hook),
      hook.settings['company_id']
    )
  end

  def records_client_for(hook)
    Crm::Yclients::Api::RecordsClient.new(
      hook.settings['partner_token'],
      Crm::Yclients::HookResolver.user_token_for(hook),
      hook.settings['company_id']
    )
  end

  def visits_client_for(hook)
    Crm::Yclients::Api::VisitsClient.new(
      hook.settings['partner_token'],
      Crm::Yclients::HookResolver.user_token_for(hook)
    )
  end

  def booking_client_for(hook)
    Crm::Yclients::Api::BookingClient.new(
      hook.settings['partner_token'],
      Crm::Yclients::HookResolver.user_token_for(hook),
      hook.settings['company_id']
    )
  end

  def find_yclients_client_id(state, hook:)
    contact = find_contact(state)
    return nil unless contact

    company_id = Crm::Yclients::HookResolver.company_id_for(hook)
    existing_id = Crm::Yclients::ContactIdentity.external_id_for(contact, company_id: company_id)
    return existing_id if existing_id.present?

    found_client = find_existing_client(contact, hook)
    return nil if found_client.blank?

    client_id = found_client['id']&.to_s
    Crm::Yclients::ContactIdentity.store_external_id(contact, client_id, company_id: company_id) if client_id.present?
    client_id
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def ensure_yclients_client_id(state, hook:)
    existing_id = find_yclients_client_id(state, hook: hook)
    return existing_id if existing_id.present?

    contact = find_contact(state)
    return nil if contact.blank?

    created = clients_client_for(hook).create(Crm::Yclients::Mappers::ContactMapper.map(contact))
    client_id = created.is_a?(Array) ? created.first&.dig('id')&.to_s : created['id']&.to_s
    return nil if client_id.blank?

    Crm::Yclients::ContactIdentity.store_external_id(
      contact,
      client_id,
      company_id: Crm::Yclients::HookResolver.company_id_for(hook)
    )
    client_id
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  def find_existing_client(contact, hook)
    client = lookup_client_by_phone(hook, contact.phone_number) if contact.phone_number.present?
    return client if client.present?

    lookup_client_by_email(hook, contact.email) if contact.email.present?
  end

  def assistant_account
    @assistant_account ||= Account.find(@assistant.account_id)
  end

  def lookup_client_by_phone(hook, phone_number)
    # rubocop:disable Rails/DynamicFindBy
    clients_client_for(hook).find_by_phone(phone_number)
    # rubocop:enable Rails/DynamicFindBy
  end

  def lookup_client_by_email(hook, email)
    # rubocop:disable Rails/DynamicFindBy
    clients_client_for(hook).find_by_email(email)
    # rubocop:enable Rails/DynamicFindBy
  end
end
