class RemoveCampaigns < ActiveRecord::Migration[7.1]
  def up
    remove_column :conversations, :campaign_id if column_exists?(:conversations, :campaign_id)
    drop_table :campaigns, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
