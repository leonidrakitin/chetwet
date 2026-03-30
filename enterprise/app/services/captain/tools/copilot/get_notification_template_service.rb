class Captain::Tools::Copilot::GetNotificationTemplateService < Captain::Tools::BaseTool
  def self.name
    'get_notification_template'
  end

  description 'Get full details of a notification template (Рассылка) by ID'

  param :template_id, type: :integer, desc: 'ID of the notification template to retrieve', required: true

  def execute(template_id:)
    template = @assistant.account.notification_templates.find_by(id: template_id)
    return 'Notification template not found' if template.nil?

    format_template(template)
  end

  private

  def format_template(template) # rubocop:disable Metrics/CyclomaticComplexity
    <<~TEMPLATE
      ID: #{template.id}
      Name: #{template.name}
      Type: #{template.template_type}
      Enabled: #{template.enabled}
      Description: #{template.description.presence || 'none'}
      Event type: #{template.event_type.presence || 'none'}
      Inbox ID: #{template.inbox_id.presence || 'none'}
      Position: #{template.position}
      Messages:
      #{format_messages(template.messages)}
      Schedule: #{json_or_none(template.schedule)}
      Conditions: #{json_or_none(template.conditions)}
      Audience: #{json_or_none(template.audience)}
      Last sent at: #{template.last_sent_at&.iso8601 || 'never'}
      Next send at: #{template.next_send_at&.iso8601 || 'not scheduled'}
    TEMPLATE
  end

  def format_messages(messages)
    messages.map.with_index(1) do |msg, i|
      text_part = "  Message #{i}: #{msg['text']}"
      buttons = msg['buttons']
      button_part = buttons.any? ? "\n    Buttons: #{buttons.map { |b| b['label'] }.join(', ')}" : ''
      "#{text_part}#{button_part}"
    end.join("\n")
  end

  def json_or_none(value)
    value.empty? ? 'none' : value.to_json
  end
end
