json.payload do
  json.array! @campaigns do |campaign|
    json.partial! 'api/v1/models/campaign', formats: [:json], resource: campaign
  end
end

json.meta do
  json.yclients_enabled @yclients_integrations.any?
  json.yclients_integrations do
    json.array! @yclients_integrations do |integration|
      json.id integration.id
      json.salon_id integration.salon_id
      json.inbox_id integration.inbox_id
      json.status integration.status
    end
  end
end
