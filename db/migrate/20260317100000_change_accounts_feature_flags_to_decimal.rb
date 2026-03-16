# frozen_string_literal: true

class ChangeAccountsFeatureFlagsToDecimal < ActiveRecord::Migration[7.1]
  def up
    change_column :accounts, :feature_flags, :decimal, precision: 20, scale: 0, default: 0, null: false
  end

  def down
    change_column :accounts, :feature_flags, :bigint, default: 0, null: false
  end
end
