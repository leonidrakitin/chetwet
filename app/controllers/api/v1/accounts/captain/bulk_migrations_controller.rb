# frozen_string_literal: true

class Api::V1::Accounts::Captain::BulkMigrationsController < Api::V1::Accounts::BaseController
  before_action :set_migration, only: [:show]

  def index
    migrations = Current.account.bulk_migrations.recent.limit(20)
    render json: migrations.map { |m| migration_json(m) }
  end

  def show
    render json: migration_json(@migration)
  end

  def create
    migration = Current.account.bulk_migrations.new(migration_params)
    if migration.save
      render json: migration_json(migration), status: :created
    else
      render json: { errors: migration.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_migration
    @migration = Current.account.bulk_migrations.find(params[:id])
  end

  def migration_params
    params.require(:bulk_migration).permit(
      :source, :captain_assistant_id, :inbox_id,
      :agent_external_id, :include_groups, :max_messages_per_dialog, :dry_run, :file,
      :telegram_session_id,
      config: %i[session_gap_minutes faq_dedup_threshold dialog_dedup_threshold max_chats max_messages_per_chat date_limit_months vk_access_token]
    )
  end

  def migration_json(migration)
    {
      id: migration.id,
      source: migration.source,
      status: migration.status,
      total_dialogs: migration.total_dialogs,
      processed: migration.processed,
      skipped: migration.skipped,
      faqs_generated: migration.faqs_generated,
      progress_percent: migration.progress_percent,
      report: migration.report,
      started_at: migration.started_at,
      finished_at: migration.finished_at,
      created_at: migration.created_at,
      dry_run: migration.dry_run
    }
  end
end
