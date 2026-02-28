# frozen_string_literal: true

class FixCaptainAssistantResponsesSequence < ActiveRecord::Migration[7.0]
  def up
    return unless connection.adapter_name == 'PostgreSQL'

    execute(<<-SQL.squish)
      SELECT setval(
        pg_get_serial_sequence('captain_assistant_responses', 'id'),
        COALESCE((SELECT MAX(id) FROM captain_assistant_responses), 1)
      )
    SQL
  end

  def down
    # Sequence reset is not reversible; no-op.
  end
end
