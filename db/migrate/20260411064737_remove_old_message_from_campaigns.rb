class RemoveOldMessageFromCampaigns < ActiveRecord::Migration[7.1]
  def change
    remove_column :campaigns, :old_message if column_exists?(:campaigns, :old_message)
    remove_column :campaigns, :sender_id if column_exists?(:campaigns, :sender_id)
    remove_column :campaigns, :trigger_rules if column_exists?(:campaigns, :trigger_rules)
    remove_column :campaigns, :campaign_type if column_exists?(:campaigns, :campaign_type)
    remove_column :campaigns, :campaign_status if column_exists?(:campaigns, :campaign_status)
    remove_column :campaigns, :trigger_only_during_business_hours if column_exists?(:campaigns, :trigger_only_during_business_hours)
    remove_column :campaigns, :template_params if column_exists?(:campaigns, :template_params)
    remove_column :campaigns, :display_id if column_exists?(:campaigns, :display_id)
  end
end
