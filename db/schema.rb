# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_04_06_221030) do
  # These extensions should be enabled to support this database
  enable_extension "pg_stat_statements"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"
  enable_extension "plpgsql"
  enable_extension "vector"

  create_table "access_tokens", force: :cascade do |t|
    t.string "owner_type"
    t.bigint "owner_id"
    t.string "token"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["owner_type", "owner_id"], name: "index_access_tokens_on_owner_type_and_owner_id"
    t.index ["token"], name: "index_access_tokens_on_token", unique: true
  end

  create_table "account_saml_settings", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "sso_url"
    t.text "certificate"
    t.string "sp_entity_id"
    t.string "idp_entity_id"
    t.json "role_mappings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_account_saml_settings_on_account_id"
  end

  create_table "account_users", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "user_id"
    t.integer "role", default: 0
    t.bigint "inviter_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "active_at", precision: nil
    t.integer "availability", default: 0, null: false
    t.boolean "auto_offline", default: true, null: false
    t.bigint "custom_role_id"
    t.bigint "agent_capacity_policy_id"
    t.index ["account_id", "user_id"], name: "uniq_user_id_per_account_id", unique: true
    t.index ["account_id"], name: "index_account_users_on_account_id"
    t.index ["agent_capacity_policy_id"], name: "index_account_users_on_agent_capacity_policy_id"
    t.index ["custom_role_id"], name: "index_account_users_on_custom_role_id"
    t.index ["user_id"], name: "index_account_users_on_user_id"
  end

  create_table "accounts", id: :serial, force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "locale", default: 0
    t.string "domain", limit: 100
    t.string "support_email", limit: 100
    t.decimal "feature_flags", precision: 80, default: "0", null: false
    t.integer "auto_resolve_duration"
    t.jsonb "limits", default: {}
    t.jsonb "custom_attributes", default: {}
    t.integer "status", default: 0
    t.jsonb "internal_attributes", default: {}, null: false
    t.jsonb "settings", default: {}
    t.bigint "plan_id"
    t.index ["plan_id"], name: "index_accounts_on_plan_id"
    t.index ["status"], name: "index_accounts_on_status"
  end

  create_table "action_mailbox_inbound_emails", force: :cascade do |t|
    t.integer "status", default: 0, null: false
    t.string "message_id", null: false
    t.string "message_checksum", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["message_id", "message_checksum"], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", precision: nil, null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agent_activity_logs", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "user_id", null: false
    t.string "status", null: false
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.integer "duration_seconds"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "started_at", "ended_at"], name: "idx_on_account_id_started_at_ended_at_3411f4f064"
    t.index ["account_id", "user_id", "started_at"], name: "idx_on_account_id_user_id_started_at_d337db4160"
    t.index ["account_id"], name: "index_agent_activity_logs_on_account_id"
    t.index ["user_id"], name: "index_agent_activity_logs_on_user_id"
  end

  create_table "agent_bot_inboxes", force: :cascade do |t|
    t.integer "inbox_id"
    t.integer "agent_bot_id"
    t.integer "status", default: 0
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "account_id"
  end

  create_table "agent_bots", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.string "outgoing_url"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "account_id"
    t.integer "bot_type", default: 0
    t.jsonb "bot_config", default: {}
    t.index ["account_id"], name: "index_agent_bots_on_account_id"
  end

  create_table "agent_capacity_policies", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", limit: 255, null: false
    t.text "description"
    t.jsonb "exclusion_rules", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_agent_capacity_policies_on_account_id"
  end

  create_table "applied_slas", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "sla_policy_id", null: false
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "sla_status", default: 0
    t.index ["account_id", "sla_policy_id", "conversation_id"], name: "index_applied_slas_on_account_sla_policy_conversation", unique: true
    t.index ["account_id"], name: "index_applied_slas_on_account_id"
    t.index ["conversation_id"], name: "index_applied_slas_on_conversation_id"
    t.index ["sla_policy_id"], name: "index_applied_slas_on_sla_policy_id"
  end

  create_table "approval_bot_configs", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "channel_type", null: false
    t.text "bot_token"
    t.string "bot_name"
    t.boolean "enabled", default: false, null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "channel_type"], name: "index_approval_bot_configs_on_account_id_and_channel_type", unique: true
    t.index ["account_id"], name: "index_approval_bot_configs_on_account_id"
  end

  create_table "article_embeddings", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.text "term", null: false
    t.vector "embedding", limit: 1024
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["embedding"], name: "index_article_embeddings_on_embedding", using: :ivfflat
  end

  create_table "articles", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "portal_id", null: false
    t.integer "category_id"
    t.integer "folder_id"
    t.string "title"
    t.text "description"
    t.text "content"
    t.integer "status"
    t.integer "views"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "author_id"
    t.bigint "associated_article_id"
    t.jsonb "meta", default: {}
    t.string "slug", null: false
    t.integer "position"
    t.string "locale", default: "en", null: false
    t.index ["account_id"], name: "index_articles_on_account_id"
    t.index ["associated_article_id"], name: "index_articles_on_associated_article_id"
    t.index ["author_id"], name: "index_articles_on_author_id"
    t.index ["portal_id"], name: "index_articles_on_portal_id"
    t.index ["slug"], name: "index_articles_on_slug", unique: true
    t.index ["status"], name: "index_articles_on_status"
    t.index ["views"], name: "index_articles_on_views"
  end

  create_table "assignment_policies", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", limit: 255, null: false
    t.text "description"
    t.integer "assignment_order", default: 0, null: false
    t.integer "conversation_priority", default: 0, null: false
    t.integer "fair_distribution_limit", default: 100, null: false
    t.integer "fair_distribution_window", default: 3600, null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "name"], name: "index_assignment_policies_on_account_id_and_name", unique: true
    t.index ["account_id"], name: "index_assignment_policies_on_account_id"
    t.index ["enabled"], name: "index_assignment_policies_on_enabled"
  end

  create_table "attachments", id: :serial, force: :cascade do |t|
    t.integer "file_type", default: 0
    t.string "external_url"
    t.float "coordinates_lat", default: 0.0
    t.float "coordinates_long", default: 0.0
    t.integer "message_id", null: false
    t.integer "account_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "fallback_title"
    t.string "extension"
    t.jsonb "meta", default: {}
    t.index ["account_id"], name: "index_attachments_on_account_id"
    t.index ["message_id"], name: "index_attachments_on_message_id"
  end

  create_table "audits", force: :cascade do |t|
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.bigint "associated_id"
    t.string "associated_type"
    t.bigint "user_id"
    t.string "user_type"
    t.string "username"
    t.string "action"
    t.jsonb "audited_changes"
    t.integer "version", default: 0
    t.string "comment"
    t.string "remote_address"
    t.string "request_uuid"
    t.datetime "created_at", precision: nil
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "automation_rules", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "event_name", null: false
    t.jsonb "conditions", default: "{}", null: false
    t.jsonb "actions", default: "{}", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "active", default: true, null: false
    t.index ["account_id"], name: "index_automation_rules_on_account_id"
  end

  create_table "bulk_migrations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "captain_assistant_id", null: false
    t.bigint "inbox_id", null: false
    t.string "source", null: false
    t.string "agent_external_id"
    t.boolean "include_groups", default: false
    t.integer "max_messages_per_dialog"
    t.string "status", default: "pending", null: false
    t.integer "total_dialogs", default: 0
    t.integer "processed", default: 0
    t.integer "skipped", default: 0
    t.integer "faqs_generated", default: 0
    t.jsonb "report", default: {}
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "dry_run", default: false, null: false
    t.bigint "telegram_session_id"
    t.jsonb "config", default: {}, null: false
    t.index ["account_id", "status"], name: "index_bulk_migrations_on_account_id_and_status"
    t.index ["account_id"], name: "index_bulk_migrations_on_account_id"
    t.index ["captain_assistant_id", "status"], name: "index_bulk_migrations_on_captain_assistant_id_and_status"
    t.index ["captain_assistant_id"], name: "index_bulk_migrations_on_captain_assistant_id"
    t.index ["inbox_id"], name: "index_bulk_migrations_on_inbox_id"
    t.index ["source"], name: "index_bulk_migrations_on_source"
    t.index ["telegram_session_id"], name: "index_bulk_migrations_on_telegram_session_id"
  end

  create_table "campaigns", force: :cascade do |t|
    t.integer "display_id", null: false
    t.string "title", null: false
    t.text "description"
    t.text "message", null: false
    t.integer "sender_id"
    t.boolean "enabled", default: true
    t.bigint "account_id", null: false
    t.bigint "inbox_id", null: false
    t.jsonb "trigger_rules", default: {}
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "campaign_type", default: 0, null: false
    t.integer "campaign_status", default: 0, null: false
    t.jsonb "audience", default: []
    t.datetime "scheduled_at", precision: nil
    t.boolean "trigger_only_during_business_hours", default: false
    t.jsonb "messages"
    t.jsonb "template_params"
    t.index ["account_id"], name: "index_campaigns_on_account_id"
    t.index ["campaign_status"], name: "index_campaigns_on_campaign_status"
    t.index ["campaign_type"], name: "index_campaigns_on_campaign_type"
    t.index ["inbox_id"], name: "index_campaigns_on_inbox_id"
    t.index ["scheduled_at"], name: "index_campaigns_on_scheduled_at"
  end

  create_table "canned_responses", id: :serial, force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "short_code"
    t.text "content"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "captain_approval_requests", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "conversation_id", null: false
    t.bigint "assistant_id"
    t.string "title", null: false
    t.text "context"
    t.jsonb "options", default: [], null: false
    t.integer "selected_option_index"
    t.text "custom_response"
    t.integer "status", default: 0, null: false
    t.string "assignee_type"
    t.bigint "assignee_id"
    t.bigint "resolved_by_id"
    t.string "messenger_type"
    t.string "messenger_message_id"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_captain_approval_requests_on_account_id"
    t.index ["assignee_type", "assignee_id", "status"], name: "idx_on_assignee_type_assignee_id_status_eee2bf9c60"
    t.index ["assistant_id"], name: "index_captain_approval_requests_on_assistant_id"
    t.index ["conversation_id", "status"], name: "index_captain_approval_requests_on_conversation_id_and_status"
    t.index ["conversation_id"], name: "index_captain_approval_requests_on_conversation_id"
    t.index ["resolved_by_id"], name: "index_captain_approval_requests_on_resolved_by_id"
  end

