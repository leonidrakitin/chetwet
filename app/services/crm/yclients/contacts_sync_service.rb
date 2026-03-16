# frozen_string_literal: true

class Crm::Yclients::ContactsSyncService
  def initialize(account, hook)
    @account = account
    @hook = hook
    @company_id = hook.settings['company_id']
    @clients_client = Crm::Yclients::Api::ClientsClient.new(
      hook.settings['partner_token'],
      Crm::Yclients::HookResolver.user_token_for(hook),
      hook.settings['company_id']
    )
  end

  def sync_all
    @contact_ids_synced_from_yclients = Set.new
    page = 1
    total_synced = 0

    loop do
      clients = @clients_client.list(page: page, count: 100)
      break if clients.blank?

      clients.each do |client_data|
        contact = find_or_create_from_yclients(client_data)
        @contact_ids_synced_from_yclients << contact.id if contact
        total_synced += 1
      end

      break if clients.size < 100

      page += 1
    end

    total_synced
  end

  def push_contacts_to_yclients
    pushed = 0
    contact_ids_just_synced = @contact_ids_synced_from_yclients || Set.new
    contacts_linked_to_company.find_each do |contact|
      next if contact_ids_just_synced.include?(contact.id)
      next unless should_push_contact?(contact)

      yclients_id = Crm::Yclients::ContactIdentity.external_id_for(contact, company_id: @company_id)
      next if yclients_id.blank?

      data = Crm::Yclients::Mappers::ContactMapper.map(contact)
      next if data['phone'].blank? && data['email'].blank?

      @clients_client.update(yclients_id, data)
      mark_source_synced(contact)
      pushed += 1
    rescue Crm::Yclients::Api::BaseClient::ApiError => e
      Rails.logger.warn "YClients ContactsSyncService: push failed for contact #{contact.id}: #{e.message}"
    end
    pushed
  end

  def find_or_create_from_yclients(client_data)
    client_data = client_data.with_indifferent_access if client_data.is_a?(Hash)
    yclients_id = client_data['id']&.to_s

    contact = find_existing_contact(client_data, yclients_id)

    if contact
      update_existing_contact(contact, client_data)
    else
      contact = create_contact(client_data)
    end

    sync_note_from_yclients_comment(contact, client_data['comment']) if contact
    store_yclients_id(contact, yclients_id) if contact && yclients_id.present?
    contact
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "YClients ContactsSyncService: failed to sync client #{client_data['id']}: #{e.message}"
    nil
  end

  private

  def find_existing_contact(client_data, yclients_id)
    if yclients_id.present?
      contact = Crm::Yclients::ContactIdentity.find_contact_by_external_id(
        @account,
        yclients_id,
        company_id: @company_id
      )
      return contact if contact
    end

    phone = client_data['phone'].presence
    email = client_data['email'].presence

    contact = @account.contacts.find_by(phone_number: phone) if phone.present?
    contact ||= find_contact_by_email(email) if email.present?
    contact
  end

  def create_contact(client_data)
    mapped = Crm::Yclients::Mappers::ContactMapper.map_from_yclients_full(client_data.to_h)
    return nil if mapped[:phone_number].blank? && mapped[:email].blank?

    yclients_attrs = mapped.delete(:yclients_attributes) || {}
    company_attrs = yclients_attrs.merge(source_attrs_from_yclients(client_data))
    additional = {}
    additional['yclients'] = yclients_attrs if yclients_attrs.any?
    additional['yclients_companies'] = { @company_id.to_s => company_attrs } if @company_id.present?

    @account.contacts.create!(mapped.merge(additional_attributes: additional))
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def update_existing_contact(contact, client_data)
    mapped = Crm::Yclients::Mappers::ContactMapper.map_from_yclients_full(client_data.to_h)
    updates = {}
    updates[:name] = mapped[:name] if mapped[:name].present?
    updates[:phone_number] = mapped[:phone_number] if mapped[:phone_number].present?
    updates[:email] = mapped[:email] if mapped[:email].present?

    company_attrs = (mapped[:yclients_attributes] || {}).merge(source_attrs_from_yclients(client_data))
    if company_attrs.present?
      attrs = (contact.additional_attributes || {}).deep_dup
      attrs['yclients'] = (attrs['yclients'] || {}).merge(mapped[:yclients_attributes] || {})
      attrs['yclients_companies'] ||= {}
      attrs['yclients_companies'][@company_id.to_s] =
        (attrs['yclients_companies'][@company_id.to_s] || {}).merge(company_attrs)
      updates[:additional_attributes] = attrs
    end

    contact.update(updates) if updates.any?
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def store_yclients_id(contact, yclients_id)
    Crm::Yclients::ContactIdentity.store_external_id(
      contact,
      yclients_id,
      company_id: @company_id,
      persist_with: :update_columns
    )
  end

  def find_contact_by_email(email)
    contact = Contact.from_email(email)
    return unless contact&.account_id == @account.id

    contact
  end

  def source_attrs_from_yclients(client_data)
    {}.tap do |h|
      h['source_phone'] = client_data['phone'].to_s.presence
      h['source_email'] = client_data['email'].to_s.presence
    end.compact
  end

  def contacts_linked_to_company
    @account.contacts.where(
      "additional_attributes -> 'external' -> 'yclients_ids' ->> ? IS NOT NULL",
      @company_id.to_s
    )
  end

  def should_push_contact?(contact)
    company_data = contact.additional_attributes.dig('yclients_companies', @company_id.to_s) || {}
    source_phone = company_data['source_phone'].to_s.presence
    source_email = company_data['source_email'].to_s.presence
    (contact.phone_number.present? && source_phone.blank?) ||
      (contact.email.present? && source_email.blank?)
  end

  def mark_source_synced(contact)
    attrs = (contact.additional_attributes || {}).deep_dup
    attrs['yclients_companies'] ||= {}
    attrs['yclients_companies'][@company_id.to_s] ||= {}
    attrs['yclients_companies'][@company_id.to_s]['source_phone'] = contact.phone_number.to_s.presence
    attrs['yclients_companies'][@company_id.to_s]['source_email'] = contact.email.to_s.presence
    contact.update_columns(additional_attributes: attrs)
  end

  def sync_note_from_yclients_comment(contact, comment_text)
    return if comment_text.blank?

    last_note = contact.notes.latest.first
    return if last_note&.content == comment_text

    contact.notes.create!(content: comment_text.strip, account_id: @account.id)
  end
end
