class CreateContactSegmentMemberships < ActiveRecord::Migration[7.0]
  def change
    create_table :contact_segment_memberships do |t|
      t.bigint :contact_id, null: false
      t.bigint :contact_segment_id, null: false
      t.timestamps
    end

    add_index :contact_segment_memberships, [:contact_segment_id, :contact_id],
              unique: true, name: 'idx_segment_memberships_unique'
    add_index :contact_segment_memberships, :contact_id
    add_foreign_key :contact_segment_memberships, :contacts
    add_foreign_key :contact_segment_memberships, :contact_segments
  end
end
