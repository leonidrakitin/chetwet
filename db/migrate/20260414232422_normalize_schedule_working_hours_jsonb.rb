class NormalizeScheduleWorkingHoursJsonb < ActiveRecord::Migration[7.0]
  def up
    %w[service_schedules provider_schedules].each do |table|
      execute(<<~SQL.squish)
        UPDATE #{table}
           SET working_hours = (working_hours #>> '{}')::jsonb
         WHERE working_hours IS NOT NULL
           AND jsonb_typeof(working_hours) = 'string'
      SQL
    end
  end

  def down
    # no-op: the previous state (jsonb-encoded string) is legacy and should not be restored
  end
end
