# frozen_string_literal: true

class CreateChannelMax < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_max do |t|
      t.references :account, null: false, foreign_key: true
      t.string :bot_token, null: false
      t.string :bot_name

      t.timestamps
    end

    add_index :channel_max, :bot_token, unique: true
  end
end
