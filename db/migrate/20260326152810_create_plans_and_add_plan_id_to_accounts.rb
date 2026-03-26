class CreatePlansAndAddPlanIdToAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table :plans do |t|
      t.string :name, null: false
      t.string :display_name
      t.decimal :price, precision: 10, scale: 2, default: 0
      t.decimal :annual_price, precision: 10, scale: 2, default: 0
      t.integer :trial_days, default: 0
      t.text :description
      t.boolean :active, default: true, null: false
      t.jsonb :feature_list, default: []
      t.timestamps
    end
    add_index :plans, :name, unique: true

    add_reference :accounts, :plan, null: true, foreign_key: { on_delete: :nullify }
  end
end
