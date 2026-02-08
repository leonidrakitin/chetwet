# frozen_string_literal: true

class AddSourceToCopilotThreads < ActiveRecord::Migration[7.0]
  def change
    add_column :copilot_threads, :source, :string
    add_index :copilot_threads, [:user_id, :assistant_id, :source],
              name: 'index_copilot_threads_on_user_assistant_source'
  end
end
