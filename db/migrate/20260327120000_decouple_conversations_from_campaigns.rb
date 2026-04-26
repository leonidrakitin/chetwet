# Removes the `conversations.campaign_id` link to campaigns. The `campaigns` table
# is kept: broadcast/yclients migrations (20260411*) transform it; dropping it
# here previously broke the chain (PG "relation campaigns does not exist").
class DecoupleConversationsFromCampaigns < ActiveRecord::Migration[7.1]
  def up
    remove_index :conversations, name: 'index_conversations_on_campaign_id', if_exists: true
    remove_column :conversations, :campaign_id if column_exists?(:conversations, :campaign_id)
  end

  def down
    add_column :conversations, :campaign_id, :bigint unless column_exists?(:conversations, :campaign_id)
    add_index :conversations, :campaign_id, name: 'index_conversations_on_campaign_id' if column_exists?(:conversations,
                                                                                                         :campaign_id) && !index_exists?(
                                                                                                           :conversations, :campaign_id, name: 'index_conversations_on_campaign_id'
                                                                                                         )
  end
end
