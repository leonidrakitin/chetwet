class CreateServiceBookingItems < ActiveRecord::Migration[7.1]
  def change
    create_table :service_booking_items do |t|
      t.references :service_booking, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.integer :duration_minutes
      t.decimal :price, precision: 10, scale: 2

      t.timestamps
    end

    add_index :service_booking_items, [:service_booking_id, :position]
  end
end
