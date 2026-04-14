# frozen_string_literal: true

# Deduplicates outgoing VK messages against Chatwoot-originated messages so we do not
# create a duplicate record when VK echoes back a message we already sent.
class Vk::OutgoingMessageDeduplicator
  pattr_initialize [:inbox!, :vk_message_id!, :vk_random_id]

  # Returns true if the VK message was matched against an existing Chatwoot message.
  def perform
    return true if duplicate_message?
    return true if vk_random_id.present? && update_message_by_random_id

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
end
