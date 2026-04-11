class CreateServiceProviders < ActiveRecord::Migration[7.1]
  def change
    create_table :service_providers do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.boolean :active, default: true, null: false
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :service_providers, [:account_id, :active]
    add_index :service_providers, :name
  end
end
