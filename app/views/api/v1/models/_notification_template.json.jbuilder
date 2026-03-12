json.id resource.id
json.name resource.name
json.description resource.description
json.type resource.template_type
json.template_type resource.template_type
json.triggerEvent resource.event_type
json.event_type resource.event_type
json.enabled resource.enabled
json.order resource.position
json.position resource.position
json.messages resource.messages
json.messageText resource.messages.first&.dig('text').to_s
json.attachments resource.messages.first&.dig('attachments') || []
json.buttons resource.messages.first&.dig('buttons') || []
json.schedule resource.schedule
json.conditions resource.conditions
json.audience resource.audience
json.limits resource.limits
json.metadata resource.metadata
json.last_sent_at resource.last_sent_at&.iso8601
json.next_send_at resource.next_send_at&.iso8601
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
