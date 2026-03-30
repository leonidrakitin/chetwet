class Captain::Tools::Copilot::CreateNotificationTemplateService < Captain::Tools::BaseTool
  def self.name
    'create_notification_template'
  end

  description 'Create a new notification template (Рассылка). Requires administrator role.'

  param :name,          type: :string,  desc: 'Name of the template',                                         required: true
  param :template_type, type: :string,  desc: 'Type: event, time, interval, lost_clients, or client_consent', required: true
  param :message_text,  type: :string,  desc: 'Text content of the first message',                            required: true
  param :description,   type: :string,  desc: 'Optional description'
  param :enabled,       type: :boolean, desc: 'Whether the template is active. Defaults to true.'
  param :inbox_id,      type: :integer, desc: 'Optional inbox ID to associate with this template'

  # rubocop:disable Metrics/ParameterLists
  def execute(name:, template_type:, message_text:, description: nil, enabled: true, inbox_id: nil)
    return 'Access denied: only administrators can create notification templates' unless user_is_administrator?

    build_and_save_template(name, template_type, message_text, description, enabled, inbox_id)
  end
  # rubocop:enable Metrics/ParameterLists

  def active?
    user_is_administrator?
  end

  private

  def build_and_save_template(name, template_type, message_text, description, enabled, inbox_id) # rubocop:disable Metrics/ParameterLists
    template = @assistant.account.notification_templates.build(
      name: name,
      template_type: template_type,
      messages: [{ text: message_text }],
      description: description,
      enabled: enabled,
      inbox_id: inbox_id
    )

    if template.save
      "Notification template created successfully. ID: #{template.id}, Name: #{template.name}, Type: #{template.template_type}"
    else
      "Failed to create notification template: #{template.errors.full_messages.join(', ')}"
    end
  end

  def user_is_administrator?
    return false if @user.blank?

    account_user = AccountUser.find_by(account_id: @assistant.account_id, user_id: @user.id)
    return false if account_user.blank?

    account_user.administrator?
  end
end
