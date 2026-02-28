# frozen_string_literal: true

class AddDryRunToBulkMigrations < ActiveRecord::Migration[7.1]
  def change
    add_column :bulk_migrations, :dry_run, :boolean, default: false, null: false
  end
end
