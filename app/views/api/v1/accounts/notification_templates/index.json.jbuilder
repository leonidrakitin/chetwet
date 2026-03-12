json.payload do
  json.array! @notification_templates do |notification_template|
    json.partial! 'api/v1/models/notification_template', formats: [:json], resource: notification_template
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
