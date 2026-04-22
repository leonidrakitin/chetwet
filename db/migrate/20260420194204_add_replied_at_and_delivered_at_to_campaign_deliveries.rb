class AddRepliedAtAndDeliveredAtToCampaignDeliveries < ActiveRecord::Migration[7.1]
  def change
    add_column :campaign_deliveries, :replied_at, :datetime
    add_column :campaign_deliveries, :delivered_at, :datetime

    add_index :campaign_deliveries, [:campaign_id, :sent_at]
    add_index :campaign_deliveries, [:account_id, :sent_at]
  end
end
