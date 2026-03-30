class Captain::Tools::Copilot::ListNotificationTemplatesService < Captain::Tools::BaseTool
  def self.name
    'list_notification_templates'
  end

  description 'List all notification templates (Рассылки) for the account with basic information'

  param :enabled_only, type: :boolean, desc: 'If true, return only enabled templates. Defaults to false (all templates).'

  def execute(enabled_only: false)
    templates = @assistant.account.notification_templates.ordered
    templates = templates.active if enabled_only

    return 'No notification templates found' if templates.empty?

    lines = templates.map do |t|
      "[ID: #{t.id}] #{t.name} | type: #{t.template_type} | enabled: #{t.enabled} | #{t.description.presence || 'no description'}"
    end

    "Total: #{templates.count} template(s)\n#{lines.join("\n")}"
  end
end
