json.extract! provider, :id, :name, :description, :active, :metadata, :created_at, :updated_at

if provider.provider_schedule.present?
  json.provider_schedule do
    json.partial! 'api/v1/accounts/services/provider_schedule', provider_schedule: provider.provider_schedule
  end
end
