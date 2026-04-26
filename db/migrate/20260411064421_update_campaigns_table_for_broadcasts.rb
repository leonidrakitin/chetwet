class UpdateCampaignsTableForBroadcasts < ActiveRecord::Migration[7.1]
  def change
    # When `campaigns` was dropped earlier (e.g. old 20260327120000) or the DB was
    # reset without init, (re)create the pre-broadcasts shape: init + messages + template_params.
    ensure_pre_broadcast_campaigns_table!

    rename_column :campaigns, :title, :name if column_exists?(:campaigns, :title)
    rename_column :campaigns, :message, :old_message if column_exists?(:campaigns, :message)

    change_column_null :campaigns, :name, false unless column_exists?(:campaigns, :title)

    add_column :campaigns, :schedule, :jsonb, default: {} unless column_exists?(:campaigns, :schedule)
    add_column :campaigns, :metadata, :jsonb, default: {} unless column_exists?(:campaigns, :metadata)
    add_column :campaigns, :last_sent_at, :datetime unless column_exists?(:campaigns, :last_sent_at)
    add_column :campaigns, :yclients_integration_id, :bigint unless column_exists?(:campaigns, :yclients_integration_id)

    add_index :campaigns, :account_id unless index_exists?(:campaigns, :account_id)
    add_index :campaigns, %i[account_id enabled] unless index_exists?(:campaigns, %i[account_id enabled])
    add_index :campaigns, %i[account_id scheduled_at] unless index_exists?(:campaigns, %i[account_id scheduled_at])

    add_foreign_key :campaigns, :yclients_integrations, on_delete: :nullify unless foreign_key_exists?(:campaigns, :yclients_integrations)

    return if table_exists?(:campaign_deliveries)

    create_table :campaign_deliveries do |t|
      t.references :campaign, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.references :contact, foreign_key: true
      t.references :conversation, foreign_key: true
      t.string :status, null: false
      t.string :trigger_type
      t.datetime :sent_at
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :campaign_deliveries, :account_id unless index_exists?(:campaign_deliveries, :account_id)
    add_index :campaign_deliveries, %i[campaign_id status] unless index_exists?(:campaign_deliveries, %i[campaign_id status])
    add_index :campaign_deliveries, %i[contact_id campaign_id] unless index_exists?(:campaign_deliveries, %i[contact_id campaign_id])
  end

  def ensure_pre_broadcast_campaigns_table!
    return if table_exists?(:campaigns)

    create_table :campaigns do |t|
      t.integer :display_id, null: false
      t.string :title, null: false
      t.text :description
      t.text :message, null: false
      t.integer :sender_id
      t.boolean :enabled, default: true
      t.bigint :account_id, null: false
      t.bigint :inbox_id, null: false
      t.jsonb :trigger_rules, default: {}
      t.jsonb :audience, default: []
      t.datetime :scheduled_at, precision: nil
      t.integer :campaign_type, default: 0, null: false
      t.integer :campaign_status, default: 0, null: false
      t.boolean :trigger_only_during_business_hours, default: false
      t.jsonb :messages
      t.jsonb :template_params
      t.timestamps
    end

    add_index :campaigns, :account_id unless index_exists?(:campaigns, :account_id)
    add_index :campaigns, :campaign_status unless index_exists?(:campaigns, :campaign_status)
    add_index :campaigns, :campaign_type unless index_exists?(:campaigns, :campaign_type)
    add_index :campaigns, :inbox_id unless index_exists?(:campaigns, :inbox_id)
    add_index :campaigns, :scheduled_at unless index_exists?(:campaigns, :scheduled_at)
  end
end
