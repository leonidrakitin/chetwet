# frozen_string_literal: true

# Deduplicates outgoing VK messages against Chatwoot-originated messages so we do not
# create a duplicate record when VK echoes back a message we already sent.
class Vk::OutgoingMessageDeduplicator
  pattr_initialize [:inbox!, :conversation, :vk_message_id!, :vk_random_id, :content]

  # Returns true if the VK message was matched against an existing Chatwoot message.
  def perform
    return true if duplicate_message?
    return true if vk_random_id.present? && update_message_by_random_id
    return false unless conversation

    return true if update_pending_chatwoot_message
    return true if update_recent_chatwoot_message_fallback

    false
  end

  private

  def duplicate_message?
    exists = inbox.messages.exists?(source_id: vk_message_id.to_s)
    Rails.logger.info "[VK] Skip outgoing sync: source_id=#{vk_message_id} already exists" if exists
    exists
  end

  def update_message_by_random_id
    pending = inbox.messages.outgoing
                   .where("external_source_ids->>'vk_random_id' = ?", vk_random_id.to_s)
                   .first
    return false unless pending

    pending.update!(source_id: vk_message_id.to_s)
    Rails.logger.info "[VK] Updated message #{pending.id} with source_id via random_id deduplication"
    true
  end

  def update_pending_chatwoot_message
    pending = conversation.messages.outgoing
                          .where(source_id: [nil, ''])
                          .where(content: content)
                          .where('created_at > ?', 2.minutes.ago)
                          .order(created_at: :desc)
                          .first
    return false unless pending

    update_message_source_from_vk!(pending)
    Rails.logger.info "[VK] Updated message #{pending.id} via pending message deduplication"
    true
  end

  def update_recent_chatwoot_message_fallback
    pending = inbox.messages.outgoing
                   .where(source_id: [nil, ''])
                   .where(content: content)
                   .where(sender_type: %w[User Captain::Assistant])
                   .where('created_at > ?', 2.minutes.ago)
                   .order(created_at: :desc)
                   .first
    return false unless pending

    update_message_source_from_vk!(pending)
    Rails.logger.info "[VK] Updated message #{pending.id} via inbox-level fallback deduplication"
    true
  end

  def update_message_source_from_vk!(message)
    attrs = { source_id: vk_message_id.to_s }
    attrs[:external_source_ids] = (message.external_source_ids || {}).merge('vk_random_id' => vk_random_id.to_s) if vk_random_id.present?
    message.update!(attrs)
  end
end
