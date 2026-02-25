# frozen_string_literal: true

class CreateChannelAvito < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_avito do |t|
      t.references :account, null: false, foreign_key: true
      t.string :client_id, null: false
      t.string :client_secret, null: false
      t.bigint :avito_user_id
      t.string :access_token
      t.datetime :token_expires_at
      t.string :avito_user_name

      t.timestamps
    end

    add_index :channel_avito, :client_id, unique: true
    add_index :channel_avito, :avito_user_id
  end
end
