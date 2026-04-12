class AddIndexToMessagesVkRandomId < ActiveRecord::Migration[7.1]
  def change
    add_index :messages, "(external_source_ids->>'vk_random_id')",
              name: 'index_messages_on_vk_random_id',
              where: "(external_source_ids->>'vk_random_id') IS NOT NULL"
  end
end
