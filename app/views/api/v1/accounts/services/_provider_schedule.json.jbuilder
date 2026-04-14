json.extract! provider_schedule, :id, :timezone, :holidays, :breaks,
              :inherit_account_schedule, :created_at, :updated_at
json.working_hours provider_schedule.normalized_working_hours
json.service_provider_id provider_schedule.service_provider_id
