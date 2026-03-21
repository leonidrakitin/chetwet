# frozen_string_literal: true

class AddOauthFieldsToChannelVk < ActiveRecord::Migration[7.0]
  def change
    change_table :channel_vk, bulk: true do |t|
      t.bigint :vk_user_id
      t.string :refresh_token
      t.datetime :token_expires_at
    end
  end
end
