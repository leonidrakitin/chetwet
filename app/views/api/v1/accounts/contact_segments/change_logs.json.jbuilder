json.data @logs do |log|
  json.id log.id
  json.action log.action
  json.trigger_source log.trigger_source
  json.reason log.reason
  json.detected_at log.detected_at.iso8601
  json.contact do
    json.id log.contact.id
    json.name log.contact.name
    json.email log.contact.email
  end
end
json.meta do
  json.current_page @logs.current_page
  json.total_pages @logs.total_pages
  json.total_count @logs.total_count
end
