class Webhooks::YclientsController < ActionController::API
  before_action :find_hook
  before_action :verify_token!

  def process_payload
    case params[:resource]
    when 'record'
      handle_record_event
    when 'client'
      handle_client_event
    end

    head :ok
  end

  private

  def find_hook
    @hook = Integrations::Hook.find_by(app_id: 'yclients', access_token: params[:token])
    head :unauthorized if @hook.blank?
  end

  def verify_token!
    head :unauthorized if @hook.blank? || @hook.disabled?
  end

  def handle_record_event
    record_data = params[:data]
    return if record_data.blank?

    client_data = record_data[:client] || {}
    contact = find_or_create_contact(client_data)
    return if contact.blank?

    store_record_metadata(contact, record_data)
  end

  def handle_client_event
    client_data = params[:data]
    return if client_data.blank?

    contact = find_or_create_contact(client_data)
    return if contact.blank?

    update_contact_from_yclients(contact, client_data)
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def find_or_create_contact(client_data)
    company_id = Crm::Yclients::HookResolver.company_id_for(@hook)
    yclients_id = client_data[:id]&.to_s
    phone = client_data[:phone].presence
    email = client_data[:email].presence

    contact = Crm::Yclients::ContactIdentity.find_contact_by_external_id(
      @hook.account,
      yclients_id,
      company_id: company_id
    )
    contact ||= @hook.account.contacts.find_by(phone_number: phone) if phone.present?
    contact ||= find_contact_by_email(email) if email.present?

    if contact.blank?
      attrs = Crm::Yclients::Mappers::ContactMapper.map_from_yclients(client_data.to_h)
      return nil if attrs[:phone_number].blank? && attrs[:email].blank?

      contact = @hook.account.contacts.create!(attrs)
    end

    store_yclients_id(contact, yclients_id) if yclients_id.present?
    contact
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "YClients webhook: failed to create contact: #{e.message}"
    nil
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def update_contact_from_yclients(contact, client_data)
    mapped = Crm::Yclients::Mappers::ContactMapper.map_from_yclients_full(client_data.to_h)
    updates = {}
    updates[:name] = mapped[:name] if mapped[:name].present? && contact.name.blank?
    updates[:phone_number] = mapped[:phone_number] if mapped[:phone_number].present? && contact.phone_number.blank?
    updates[:email] = mapped[:email] if mapped[:email].present? && contact.email.blank?

    if mapped[:yclients_attributes].present?
      Crm::Yclients::ContactIdentity.merge_company_attributes(
        contact,
        company_id: Crm::Yclients::HookResolver.company_id_for(@hook),
        attributes: mapped[:yclients_attributes]
      )
    end

    contact.update(updates) if updates.any?
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def store_record_metadata(contact, record_data)
    record_id = record_data[:id]&.to_s
    return if record_id.blank?

    conversation = find_conversation_by_record(record_id)

    unless conversation
      inbox = @hook.inbox || @hook.account.inboxes.first
      return if inbox.blank?

      conversation = @hook.account.conversations.create!(
        contact_id: contact.id,
        inbox_id: inbox.id,
        contact_inbox: contact.contact_inboxes.find_or_create_by!(inbox: inbox)
      )
    end

    metadata = Crm::Yclients::Mappers::RecordMapper.map_to_metadata(
      record_data.to_h.merge('company_id' => Crm::Yclients::HookResolver.company_id_for(@hook))
    )
    existing = conversation.additional_attributes || {}
    conversation.update!(additional_attributes: existing.merge('yclients' => metadata))
  end

  def find_conversation_by_record(record_id)
    company_id = Crm::Yclients::HookResolver.company_id_for(@hook)
    query = <<~SQL.squish
      ((additional_attributes -> 'yclients' ->> 'record_id' = ?)
        AND (additional_attributes -> 'yclients' ->> 'company_id' = ?))
      OR
      ((additional_attributes -> 'yclients' ->> 'record_id' = ?)
        AND (additional_attributes -> 'yclients' ->> 'company_id' IS NULL))
    SQL

    @hook.account.conversations.find_by(
      query,
      record_id,
      company_id,
      record_id,
      record_id
    )
  end

  def store_yclients_id(contact, yclients_id)
    Crm::Yclients::ContactIdentity.store_external_id(
      contact,
      yclients_id,
      company_id: Crm::Yclients::HookResolver.company_id_for(@hook),
      persist_with: :update_columns
    )
  end

  def find_contact_by_email(email)
    contact = Contact.from_email(email)
    return unless contact&.account_id == @hook.account_id

    contact
  end
end
