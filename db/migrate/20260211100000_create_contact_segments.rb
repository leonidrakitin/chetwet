class CreateContactSegments < ActiveRecord::Migration[7.0]
  def change
    create_table :contact_segments do |t|
      t.string :name, null: false
      t.text :description
      t.jsonb :query, null: false, default: {}
      t.references :account, null: false, foreign_key: true
      t.bigint :created_by_id
      t.boolean :active, default: true
      t.boolean :triggers_enabled, default: false
      t.timestamps
    end

    add_foreign_key :contact_segments, :users, column: :created_by_id
  end
end
