class CreateServices < ActiveRecord::Migration[7.1]
  def change
    create_table :services do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :duration_minutes, null: false, default: 30
      t.decimal :price, precision: 10, scale: 2
      t.string :currency, default: 'RUB'
      t.boolean :active, default: true, null: false
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :services, [:account_id, :active]
    add_index :services, :name
  end
end
