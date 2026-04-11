class CreateLlmUsages < ActiveRecord::Migration[7.1]
  def change
    create_table :llm_usages do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :conversation, foreign_key: true, index: true
      t.references :message, foreign_key: true
      t.string :feature, null: false
      t.string :model, null: false
      t.string :provider, null: false
      t.integer :prompt_tokens, null: false, default: 0
      t.integer :completion_tokens, null: false, default: 0
      t.integer :total_tokens, null: false, default: 0
      t.integer :cache_read_tokens
      t.integer :cache_creation_tokens
      t.decimal :cost_usd, precision: 10, scale: 6, null: false, default: 0.0
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :llm_usages, %i[account_id feature]
    add_index :llm_usages, %i[account_id created_at]
    add_index :llm_usages, %i[conversation_id created_at]
  end
end
