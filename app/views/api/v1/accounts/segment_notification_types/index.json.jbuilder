json.payload do
  json.array! @notification_types do |notification_type|
    json.partial! 'notification_type', notification_type: notification_type
  end
end
