class CreateServiceBookings < ActiveRecord::Migration[7.1]
  def change
    create_table :service_bookings do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :service_provider, null: false, foreign_key: true
      t.datetime :scheduled_at, null: false
      t.integer :total_duration_minutes
      t.integer :status, default: 0, null: false
      t.text :customer_notes
      t.text :internal_notes
      t.jsonb :preferences, default: {}
      t.jsonb :metadata, default: {}
      t.datetime :cancelled_at
      t.string :cancellation_reason

      t.timestamps
    end

    add_index :service_bookings, [:account_id, :scheduled_at]
    add_index :service_bookings, [:service_provider_id, :scheduled_at]
    add_index :service_bookings, :status
  end
end
