class AddSegmentIdToCampaigns < ActiveRecord::Migration[7.0]
  def change
    add_column :campaigns, :segment_id, :bigint, null: true
    add_foreign_key :campaigns, :contact_segments, column: :segment_id
  end
end
