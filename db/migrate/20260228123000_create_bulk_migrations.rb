# frozen_string_literal: true

class CreateBulkMigrations < ActiveRecord::Migration[7.1]
  def change
    create_table :bulk_migrations do |t|
      t.references :account,           null: false, foreign_key: true, index: true
      t.references :captain_assistant, null: false, foreign_key: { to_table: :captain_assistants }, index: true
      t.references :inbox,             null: false, foreign_key: true, index: true

      t.string     :source,            null: false                     # telegram, whatsapp, vk
      t.string     :agent_external_id                                  # user_id / phone агента для парсера
      t.boolean    :include_groups,    default: false
      t.integer    :max_messages_per_dialog                            # лимит для тестов

      t.string     :status,            null: false, default: 'pending'  # pending, processing, completed, failed
      t.integer    :total_dialogs,     default: 0
      t.integer    :processed,         default: 0
      t.integer    :skipped,           default: 0
      t.integer    :faqs_generated,    default: 0

      t.jsonb      :report,            default: {}
      t.datetime   :started_at
      t.datetime   :finished_at

      t.timestamps
    end

    add_index :bulk_migrations, [:account_id, :status]
    add_index :bulk_migrations, [:captain_assistant_id, :status]
    add_index :bulk_migrations, :source
  end
end
