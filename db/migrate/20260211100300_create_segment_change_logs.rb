class CreateSegmentChangeLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :segment_change_logs do |t|
      t.bigint :contact_id, null: false
      t.bigint :contact_segment_id, null: false
      t.string :action, null: false
      t.string :trigger_source, null: false
      t.text :reason
      t.datetime :detected_at, null: false
      t.timestamps
    end

    add_index :segment_change_logs, :contact_id
    add_index :segment_change_logs, :contact_segment_id
    add_index :segment_change_logs, :detected_at
    add_foreign_key :segment_change_logs, :contacts
    add_foreign_key :segment_change_logs, :contact_segments
  end
end
