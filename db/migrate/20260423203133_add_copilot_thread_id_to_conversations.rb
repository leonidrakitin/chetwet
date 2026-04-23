class AddCopilotThreadIdToConversations < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :copilot_thread_id, :bigint, null: true
    add_index :conversations, :copilot_thread_id
  end
end
