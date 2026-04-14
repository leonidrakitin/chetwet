class AddUniqueIndexOnMessagesInboxSource < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    cleanup_duplicates!

    remove_index :messages, name: 'index_messages_on_inbox_id_and_source_id', if_exists: true, algorithm: :concurrently

    add_index :messages, %i[inbox_id source_id],
              unique: true,
              where: 'source_id IS NOT NULL',
              name: 'index_messages_on_inbox_id_and_source_id',
              algorithm: :concurrently
  end

  def down
    remove_index :messages, name: 'index_messages_on_inbox_id_and_source_id', if_exists: true, algorithm: :concurrently
  end

  private

  # Keep the message with sender_id (agent-originated), fall back to min(id).
  # Matches the VK echo race: SendReplyJob creates a message with sender, while
  # the webhook sync creates a second one with sender: nil — we drop the latter.
  def cleanup_duplicates!
    execute(<<~SQL)
      DELETE FROM messages m
      USING (
        SELECT id
        FROM (
          SELECT id,
                 ROW_NUMBER() OVER (
                   PARTITION BY inbox_id, source_id
                   ORDER BY (sender_id IS NULL), id
                 ) AS rn
          FROM messages
          WHERE source_id IS NOT NULL
        ) ranked
        WHERE ranked.rn > 1
      ) dups
      WHERE m.id = dups.id
    SQL
  end
end
