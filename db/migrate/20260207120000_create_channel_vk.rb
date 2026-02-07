# frozen_string_literal: true

class CreateChannelVk < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_vk do |t|
      t.references :account, null: false, foreign_key: true
      t.string :group_id, null: false
      t.string :access_token, null: false
      t.string :secret
      t.string :group_name

      t.timestamps
    end

    add_index :channel_vk, :group_id, unique: true
  end
end
