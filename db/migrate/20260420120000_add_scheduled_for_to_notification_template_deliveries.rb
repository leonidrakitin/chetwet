class AddScheduledForToNotificationTemplateDeliveries < ActiveRecord::Migration[7.1]
  def change
    add_column :notification_template_deliveries, :scheduled_for, :datetime
    add_index :notification_template_deliveries, [:contact_id, :scheduled_for],
              name: 'index_nt_deliveries_on_contact_scheduled_for'
    add_index :notification_template_deliveries, [:status, :scheduled_for],
              name: 'index_nt_deliveries_on_status_scheduled_for'

    change_column_null :notification_template_deliveries, :sent_at, true
  end
end
