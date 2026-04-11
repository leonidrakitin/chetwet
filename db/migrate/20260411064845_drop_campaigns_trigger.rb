class DropCampaignsTrigger < ActiveRecord::Migration[7.1]
  def up
    execute 'DROP TRIGGER IF EXISTS campaigns_before_insert_row_tr ON campaigns'
    execute 'DROP FUNCTION IF EXISTS campaigns_before_insert_row_tr()'
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
