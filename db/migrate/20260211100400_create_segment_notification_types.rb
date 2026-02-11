class CreateSegmentNotificationTypes < ActiveRecord::Migration[7.0]
  def change
    create_table :segment_notification_types do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :icon
      t.boolean :active, default: true
      t.integer :position, default: 0
      t.timestamps
    end
  end
end
