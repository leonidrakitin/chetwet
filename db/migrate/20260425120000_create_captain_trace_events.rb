class CreateCaptainTraceEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :captain_trace_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.bigint :assistant_id
      t.string :session_id, null: false
      t.bigint :source_message_id
      t.string :event_type, null: false
      t.integer :sequence, null: false
      t.jsonb :payload, default: {}, null: false

      t.datetime :created_at, null: false
    end

    add_index :captain_trace_events, :assistant_id
    add_index :captain_trace_events, :source_message_id
    add_index :captain_trace_events, [:session_id, :sequence]
    add_index :captain_trace_events, [:conversation_id, :created_at]
  end
end
