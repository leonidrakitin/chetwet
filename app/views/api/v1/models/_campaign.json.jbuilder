json.id resource.id
json.name resource.name
json.description resource.description
json.enabled resource.enabled
json.messages resource.messages
json.messageText resource.messages.first&.dig('text').to_s
json.attachments resource.messages.first&.dig('attachments') || []
json.buttons resource.messages.first&.dig('buttons') || []
json.schedule resource.schedule
json.audience resource.audience
json.metadata resource.metadata
json.last_sent_at resource.last_sent_at&.iso8601
json.scheduled_at resource.scheduled_at&.iso8601
json.inbox_id resource.inbox_id
json.yclients_integration_id resource.yclients_integration_id

if resource.inbox.present?
  json.inbox do
    json.partial! 'api/v1/models/inbox_slim', formats: [:json], resource: resource.inbox
  end
end

if resource.yclients_integration.present?
  json.yclients_integration do
    json.id resource.yclients_integration.id
    json.salon_id resource.yclients_integration.salon_id
    json.inbox_id resource.yclients_integration.inbox_id
  end
end
