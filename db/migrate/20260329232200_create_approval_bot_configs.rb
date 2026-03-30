# frozen_string_literal: true

class CreateApprovalBotConfigs < ActiveRecord::Migration[7.1]
  def change
    create_table :approval_bot_configs do |t|
      t.references :account, null: false, foreign_key: true
      t.string :channel_type, null: false
      t.text :bot_token
      t.string :bot_name
      t.boolean :enabled, null: false, default: false
      t.jsonb :settings, null: false, default: {}
      t.timestamps
    end

    add_index :approval_bot_configs, %i[account_id channel_type], unique: true
  end
end
