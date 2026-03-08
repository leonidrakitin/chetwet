# frozen_string_literal: true

class Crm::Yclients::ContactsSyncService
  def initialize(account, hook)
    @account = account
    @hook = hook
    @company_id = hook.settings['company_id']
    @clients_client = Crm::Yclients::Api::ClientsClient.new(
      hook.settings['partner_token'],
      hook.settings['user_token'],
      hook.settings['company_id']
    )
  end

  def sync_all
    page = 1
    total_synced = 0

    loop do
      clients = @clients_client.list(page: page, count: 100)
      break if clients.blank?

      clients.each do |client_data|
        find_or_create_from_yclients(client_data)
        total_synced += 1
      end

      break if clients.size < 100

      page += 1
    end

    total_synced
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
    additional = {}
    additional['yclients'] = yclients_attrs if yclients_attrs.any?
    additional['yclients_companies'] = { @company_id.to_s => yclients_attrs } if yclients_attrs.any? && @company_id.present?

    @account.contacts.create!(mapped.merge(additional_attributes: additional))
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def update_existing_contact(contact, client_data)
    mapped = Crm::Yclients::Mappers::ContactMapper.map_from_yclients_full(client_data.to_h)
    updates = {}
    updates[:name] = mapped[:name] if mapped[:name].present? && contact.name.blank?
    updates[:phone_number] = mapped[:phone_number] if mapped[:phone_number].present? && contact.phone_number.blank?
    updates[:email] = mapped[:email] if mapped[:email].present? && contact.email.blank?

    if mapped[:yclients_attributes].present?
      attrs = (contact.additional_attributes || {}).deep_dup
      attrs['yclients'] = (attrs['yclients'] || {}).merge(mapped[:yclients_attributes])
      attrs['yclients_companies'] ||= {}
      attrs['yclients_companies'][@company_id.to_s] =
        (attrs['yclients_companies'][@company_id.to_s] || {}).merge(mapped[:yclients_attributes])
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
end
