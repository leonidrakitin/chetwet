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

  def find_or_create_contact(client_data)
    phone = client_data[:phone].presence
    email = client_data[:email].presence

    contact = @hook.account.contacts.find_by(phone_number: phone) if phone.present?
    contact ||= @hook.account.contacts.find_by(email: email) if email.present?

    if contact.blank?
      attrs = Crm::Yclients::Mappers::ContactMapper.map_from_yclients(client_data.to_h)
      return nil if attrs[:phone_number].blank? && attrs[:email].blank?

      contact = @hook.account.contacts.create!(attrs)
    end

    store_yclients_id(contact, client_data[:id]&.to_s) if client_data[:id].present?
    contact
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "YClients webhook: failed to create contact: #{e.message}"
    nil
  end

  def update_contact_from_yclients(contact, client_data)
    attrs = Crm::Yclients::Mappers::ContactMapper.map_from_yclients(client_data.to_h).except(:phone_number)
    contact.update(attrs)
  end

  def store_record_metadata(contact, record_data)
    record_id = record_data[:id]&.to_s
    return if record_id.blank?

    conversation = find_conversation_by_record(record_id)

    unless conversation
      inbox = @hook.account.inboxes.first
      return if inbox.blank?

      conversation = @hook.account.conversations.create!(
        contact_id: contact.id,
        inbox_id: inbox.id,
        contact_inbox: contact.contact_inboxes.find_or_create_by!(inbox: inbox)
      )
    end

    metadata = Crm::Yclients::Mappers::RecordMapper.map_to_metadata(record_data.to_h)
    existing = conversation.additional_attributes || {}
    conversation.update!(additional_attributes: existing.merge('yclients' => metadata))
  end

  def find_conversation_by_record(record_id)
    @hook.account.conversations.find_by(
      "additional_attributes -> 'yclients' ->> 'record_id' = ?", record_id
    )
  end

  def store_yclients_id(contact, yclients_id)
    attrs = contact.additional_attributes || {}
    attrs['external'] ||= {}
    return if attrs['external']['yclients_id'] == yclients_id

    attrs['external']['yclients_id'] = yclients_id
    contact.update_columns(additional_attributes: attrs)
  end
end
