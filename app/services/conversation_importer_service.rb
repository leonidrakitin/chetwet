# frozen_string_literal: true

# ConversationImporterService
# Импортирует один унифицированный диалог в Chatwoot как полноценную Conversation.
# После создания сразу переводит в :resolved → срабатывает существующая логика:
# CaptainListener → ConversationFaqService → генерация FAQ + дедупликация + embeddings.
class ConversationImporterService
  def initialize(inbox, assistant = nil)
    @inbox = inbox
    @assistant = assistant
    @account = inbox.account
  end

  # @param dialog [Hash] унифицированный диалог из парсера
  # @return [Hash] { success: true/false, conversation_id:, faqs_generated: 0, error: nil }
  def import!(dialog)
    ActiveRecord::Base.transaction do
      contact_inbox = find_or_create_contact_inbox(dialog)
      contact = contact_inbox.contact
      conversation = create_conversation(contact_inbox, dialog)
      create_messages(conversation, dialog[:messages], contact)
      finalize_conversation(conversation, dialog)
      { success: true, conversation_id: conversation.id, faqs_generated: 0, contact_id: contact.id }
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    Rails.logger.error "[ConversationImporterService] Ошибка импорта #{dialog[:external_id]}: #{e.message}"
    { success: false, error: e.message, external_id: dialog[:external_id] }
  end

  private

  def find_or_create_contact_inbox(dialog)
    ContactInboxWithContactBuilder.new(
      source_id: dialog[:contact_external_id].to_s,
      inbox: @inbox,
      contact_attributes: {
        name: dialog[:contact_name].presence || "Imported #{dialog[:source].to_s.titleize} User",
        additional_attributes: (dialog[:additional_attributes] || {}).merge('source' => dialog[:source], 'imported' => true),
        avatar_url: dialog[:contact_avatar_url]
      }
    ).perform
  end

  def create_conversation(contact_inbox, dialog)
    @inbox.conversations.create!(
      account: @account,
      contact: contact_inbox.contact,
      contact_inbox: contact_inbox,
      status: :open,
      additional_attributes: { imported: true, source: dialog[:source] }
    )
  end

  def create_messages(conversation, raw_messages, contact)
    return if raw_messages.blank?

    content_type_enum = Message.content_types
    rows = raw_messages.map { |msg| message_row(msg, conversation, contact, content_type_enum) }
    Message.insert_all!(rows) # rubocop:disable Rails/SkipsModelValidations
  end

  def message_row(msg, conversation, contact, content_type_enum)
    ct = msg[:content_type].to_s
    content_type = content_type_enum[ct == 'system' ? 'text' : ct] || content_type_enum[:text]
    incoming = msg[:sender_type] != 'agent'
    {
      account_id: @account.id,
      inbox_id: @inbox.id,
      conversation_id: conversation.id,
      message_type: message_type_for(msg[:sender_type]),
      content: msg[:content],
      content_type: content_type,
      created_at: msg[:created_at],
      updated_at: msg[:created_at],
      source_id: msg[:external_id].to_s,
      private: false,
      sender_type: incoming ? 'Contact' : nil,
      sender_id: incoming ? contact.id : nil
    }
  end

  def finalize_conversation(conversation, dialog)
    first_reply_at = first_user_reply_at(dialog[:messages])
    conversation.update!(
      status: :resolved,
      first_reply_created_at: first_reply_at,
      additional_attributes: conversation.additional_attributes.merge(
        imported_from: dialog[:source],
        migration_external_id: dialog[:external_id],
        original_title: dialog[:title]
      )
    )
    conversation.update_columns(created_at: dialog[:messages].first[:created_at]) # rubocop:disable Rails/SkipsModelValidations
  end

  def message_type_for(sender_type)
    sender_type == 'agent' ? Message.message_types[:outgoing] : Message.message_types[:incoming]
  end

  def first_user_reply_at(messages)
    first_user_msg = messages.find { |m| m[:sender_type] == 'user' }
    first_user_msg ? first_user_msg[:created_at] : messages.first[:created_at]
  end
end
