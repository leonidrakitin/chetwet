class CreateNotificationTemplates < ActiveRecord::Migration[7.0]
  def change
    create_table :notification_templates do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, foreign_key: true
      t.references :yclients_integration, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :template_type, null: false, default: 'event'
      t.string :event_type
      t.boolean :enabled, null: false, default: true
      t.integer :position, null: false, default: 0
      t.jsonb :messages, null: false, default: []
      t.jsonb :schedule, null: false, default: {}
      t.jsonb :conditions, null: false, default: {}
      t.jsonb :audience, null: false, default: {}
      t.jsonb :limits, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.datetime :last_sent_at
      t.datetime :next_send_at

      t.timestamps
    end

    add_index :notification_templates, [:account_id, :template_type]
    add_index :notification_templates, [:account_id, :enabled]
    add_index :notification_templates, [:account_id, :position]
    add_index :notification_templates, [:account_id, :next_send_at]

    create_table :notification_template_deliveries do |t|
      t.references :notification_template, null: false, foreign_key: true, index: { name: 'index_nt_deliveries_on_template_id' }
      t.references :account, null: false, foreign_key: true
      t.references :contact, foreign_key: true
      t.references :conversation, foreign_key: true
      t.string :status, null: false, default: 'sent'
      t.string :trigger_type
      t.datetime :sent_at, null: false
      t.datetime :responded_at
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :notification_template_deliveries,
              [:notification_template_id, :contact_id, :sent_at],
              name: 'index_nt_deliveries_on_template_contact_sent_at'
    add_index :notification_template_deliveries, [:account_id, :contact_id, :sent_at], name: 'index_nt_deliveries_on_account_contact_sent_at'
    add_index :notification_template_deliveries, [:conversation_id, :sent_at], name: 'index_nt_deliveries_on_conversation_sent_at'
  end
end
