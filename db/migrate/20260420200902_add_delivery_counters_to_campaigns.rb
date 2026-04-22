class AddDeliveryCountersToCampaigns < ActiveRecord::Migration[7.1]
  def change
    add_column :campaigns, :audience_count, :integer, default: 0, null: false
    add_column :campaigns, :sent_count, :integer, default: 0, null: false
    add_column :campaigns, :failed_count, :integer, default: 0, null: false
  end
end
