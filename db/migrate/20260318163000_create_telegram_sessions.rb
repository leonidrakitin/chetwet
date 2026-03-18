class CreateTelegramSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :channel_telegram_personal do |t|
      t.references :account, null: false, foreign_key: true
      t.string :title
      t.string :telegram_user_id
      t.string :telegram_username
      t.string :status, null: false, default: 'disconnected'
      t.text :last_error

      t.timestamps
    end

    create_table :telegram_sessions do |t|
      t.string :phone_number, null: false
      t.text :encrypted_session_data
      t.string :api_id, null: false
      t.string :api_hash, null: false
      t.integer :status, null: false, default: 0
      t.string :auth_state
      t.text :last_error
      t.jsonb :metadata, null: false, default: {}
      t.references :user, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true

      t.timestamps
    end

    add_index :telegram_sessions, :phone_number
    add_index :telegram_sessions, :inbox_id, unique: true
  end
end
