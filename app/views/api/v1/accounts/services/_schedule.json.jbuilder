json.extract! schedule, :id, :timezone, :holidays, :breaks,
              :slot_interval_minutes, :created_at, :updated_at
json.working_hours schedule.normalized_working_hours
