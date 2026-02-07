# frozen_string_literal: true

class Vk::TypingStatusService
  include Events::Types

  pattr_initialize [:inbox!, :params!]

  def perform
    return unless valid_typing_event?

    find_contact_and_conversation
    return unless @conversation

    trigger_typing_event
  end

  private

  def valid_typing_event?
    from_id.present? && typing_state.present?
  end

  def from_id
    params[:from_id]
  end

  def typing_state
    params[:state]
  end

  def find_contact_and_conversation
    contact_inbox = inbox.contact_inboxes.find_by(source_id: from_id.to_s)
    return unless contact_inbox

    @contact = contact_inbox.contact
    @conversation = contact_inbox.conversations.where.not(status: :resolved).last
  end

  def trigger_typing_event
    event = typing_state == 'typing' ? CONVERSATION_TYPING_ON : CONVERSATION_TYPING_OFF
    Rails.configuration.dispatcher.dispatch(event, Time.zone.now, conversation: @conversation, user: @contact, is_private: false)
  end
end
