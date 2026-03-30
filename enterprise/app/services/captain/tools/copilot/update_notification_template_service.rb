class Captain::Tools::Copilot::UpdateNotificationTemplateService < Captain::Tools::BaseTool
  def self.name
    'update_notification_template'
  end

  description 'Update an existing notification template (Рассылка). Requires administrator role.'

  param :template_id,  type: :integer, desc: 'ID of the template to update',              required: true
  param :name,         type: :string,  desc: 'New name for the template'
  param :description,  type: :string,  desc: 'New description'
  param :enabled,      type: :boolean, desc: 'Enable or disable the template'
  param :message_text, type: :string,  desc: 'Replace the first message text with this value'

  def execute(template_id:, name: nil, description: nil, enabled: nil, message_text: nil)
    return 'Access denied: only administrators can update notification templates' unless user_is_administrator?

    template = @assistant.account.notification_templates.find_by(id: template_id)
    return 'Notification template not found' if template.nil?

    attrs = build_attrs(name, description, enabled, message_text, template)
    save_template(template, attrs)
  end

  def active?
    user_is_administrator?
  end

  private

  def build_attrs(name, description, enabled, message_text, template)
    attrs = {}
    attrs[:name]        = name        if name.present?
    attrs[:description] = description if description.present?
    attrs[:enabled]     = enabled     unless enabled.nil?
    attrs[:messages]    = updated_messages(template.messages, message_text) if message_text.present?
    attrs
  end

  def updated_messages(existing, message_text)
    messages = existing.dup
    messages[0] = (messages[0] || {}).merge('text' => message_text)
    messages
  end

  def save_template(template, attrs)
    if template.update(attrs)
      "Notification template #{template.id} updated successfully. Name: #{template.name}, Enabled: #{template.enabled}"
    else
      "Failed to update notification template: #{template.errors.full_messages.join(', ')}"
    end
  end

  def user_is_administrator?
    return false if @user.blank?

    account_user = AccountUser.find_by(account_id: @assistant.account_id, user_id: @user.id)
    return false if account_user.blank?

    account_user.administrator?
  end
end
