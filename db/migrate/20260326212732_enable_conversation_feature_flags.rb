class EnableConversationFeatureFlags < ActiveRecord::Migration[7.1]
  def up
    Account.find_each do |account|
      account.enable_features!(
        :conversation_assignee,
        :conversation_team,
        :conversation_priority,
        :conversation_labels
      )
    end
  end

  def down; end
end
