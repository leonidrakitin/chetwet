# frozen_string_literal: true

class AddTelegramLiveFieldsToBulkMigrations < ActiveRecord::Migration[7.0]
  def change
    add_reference :bulk_migrations, :telegram_session, foreign_key: true, null: true
    add_column :bulk_migrations, :config, :jsonb, default: {}, null: false
  end
end
