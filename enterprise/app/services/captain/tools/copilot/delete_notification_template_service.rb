class Captain::Tools::Copilot::DeleteNotificationTemplateService < Captain::Tools::BaseTool
  def self.name
    'delete_notification_template'
  end

  description 'Delete a notification template (Рассылка) permanently. Requires administrator role. This action cannot be undone.'

  param :template_id, type: :integer, desc: 'ID of the notification template to delete', required: true

  def execute(template_id:)
    return 'Access denied: only administrators can delete notification templates' unless user_is_administrator?

    template = @assistant.account.notification_templates.find_by(id: template_id)
    return 'Notification template not found' if template.nil?

    template_name = template.name
    template.destroy!

    "Notification template '#{template_name}' (ID: #{template_id}) has been permanently deleted"
  rescue ActiveRecord::RecordNotDestroyed => e
    "Failed to delete notification template: #{e.message}"
  end

  def active?
    user_is_administrator?
  end

  private

  def user_is_administrator?
    return false if @user.blank?

    account_user = AccountUser.find_by(account_id: @assistant.account_id, user_id: @user.id)
    return false if account_user.blank?

    account_user.administrator?
  end
end
