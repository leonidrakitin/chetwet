# frozen_string_literal: true

class CreateYclientsIntegrations < ActiveRecord::Migration[7.1]
  def change
    create_table :yclients_integrations do |t|
      t.references :account, null: false, index: true
      t.integer :salon_id, null: false
      t.string :bearer_token
      t.datetime :connected_at
      t.integer :status, default: 0, null: false
      t.string :webhook_secret
      t.string :system_user_id

      t.timestamps
    end

    add_index :yclients_integrations, [:account_id, :salon_id], unique: true
    add_index :yclients_integrations, :salon_id
  end
end
