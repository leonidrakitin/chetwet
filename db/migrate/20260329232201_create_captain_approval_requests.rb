# frozen_string_literal: true

class CreateCaptainApprovalRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :captain_approval_requests do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :assistant, null: true, foreign_key: { to_table: :captain_assistants }
      t.string :title, null: false
      t.text :context
      t.jsonb :options, null: false, default: []
      t.integer :selected_option_index
      t.text :custom_response
      t.integer :status, null: false, default: 0
      t.string :assignee_type
      t.bigint :assignee_id
      t.references :resolved_by, null: true, foreign_key: { to_table: :users }
      t.string :messenger_type
      t.string :messenger_message_id
      t.datetime :expires_at
      t.timestamps
    end

    add_index :captain_approval_requests, %i[conversation_id status]
    add_index :captain_approval_requests, %i[assignee_type assignee_id status]
  end
end
