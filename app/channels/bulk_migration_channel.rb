# frozen_string_literal: true

class BulkMigrationChannel < ApplicationCable::Channel
  def subscribed
    stream_from "bulk_migration_#{params[:migration_id]}"
  end

  def unsubscribed
    stop_all_streams
  end
end
