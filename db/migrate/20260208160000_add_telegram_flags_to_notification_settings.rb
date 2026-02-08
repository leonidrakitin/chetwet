# frozen_string_literal: true

class AddTelegramFlagsToNotificationSettings < ActiveRecord::Migration[7.0]
  def change
    add_column :notification_settings, :telegram_flags, :integer, default: 0, null: false
  end
end
