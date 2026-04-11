class MakeCampaignInboxIdNullable < ActiveRecord::Migration[7.1]
  def change
    change_column_null :campaigns, :inbox_id, true
  end
end
