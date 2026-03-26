class IncreaseFeatureFlagsPrecision < ActiveRecord::Migration[7.1]
  def change
    change_column :accounts, :feature_flags, :decimal, precision: 80, scale: 0, default: 0, null: false
  end
end
