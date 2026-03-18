module Chatwoot
  module API
    module_function

    def find_or_create_contact_inbox(inbox:, source_id:, contact_attributes:)
      ::ContactInboxWithContactBuilder.new(
        source_id: source_id,
        inbox: inbox,
        contact_attributes: contact_attributes
      ).perform
    end

    def find_or_create_conversation(inbox:, contact_inbox:, additional_attributes: {})
      ActiveRecord::Base.transaction do
        contact_inbox.lock!

        conversation = if inbox.lock_to_single_conversation
                         contact_inbox.conversations.last
                       else
                         contact_inbox.conversations.where.not(status: :resolved).last
                       end

        conversation ||= ::Conversation.create!(
          account_id: inbox.account_id,
          inbox_id: inbox.id,
          contact_id: contact_inbox.contact_id,
          contact_inbox_id: contact_inbox.id,
          additional_attributes: additional_attributes
        )

        merge_conversation_attributes!(conversation, additional_attributes)
        conversation
      end
    end

    def create_message(conversation:, attributes:)
      conversation.messages.create!(attributes)
    end

    def update_message(inbox:, source_id:, attributes:)
      message = inbox.messages.find_by(source_id: source_id.to_s)
      return unless message

      message.update!(attributes)
      message
    end

    def find_message(inbox:, source_id:)
      inbox.messages.find_by(source_id: source_id.to_s)
    end

    def mark_message_deleted!(message)
      message.update!(
        content: I18n.t('conversations.messages.deleted'),
        content_type: :text,
        content_attributes: (message.content_attributes || {}).merge('deleted' => true)
      )
    end

    def merge_conversation_attributes!(conversation, attributes)
      merged = (conversation.additional_attributes || {}).merge(attributes.deep_stringify_keys)
      conversation.update!(additional_attributes: merged) if merged != conversation.additional_attributes
    end
  end
end
