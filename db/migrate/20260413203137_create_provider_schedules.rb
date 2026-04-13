class CreateProviderSchedules < ActiveRecord::Migration[7.1]
  def change
    create_table :provider_schedules do |t|
      t.references :service_provider, null: false, foreign_key: true, index: { unique: true }
      t.jsonb :working_hours
      t.jsonb :breaks
      t.jsonb :holidays
      t.string :timezone, default: 'UTC', null: false
      t.boolean :inherit_account_schedule, default: true, null: false

      t.timestamps
    end
  end
end
