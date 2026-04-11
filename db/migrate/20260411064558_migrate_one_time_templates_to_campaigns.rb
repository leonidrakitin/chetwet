class MigrateOneTimeTemplatesToCampaigns < ActiveRecord::Migration[7.1]
  def up
    NotificationTemplate.where(template_type: 'one_time').find_each do |template|
      campaign = Campaign.create!(
        account_id: template.account_id,
        inbox_id: template.inbox_id,
        yclients_integration_id: template.yclients_integration_id,
        name: template.name,
        description: template.description,
        enabled: template.enabled,
        schedule: template.schedule,
        audience: template.audience,
        messages: template.messages,
        metadata: template.metadata,
        last_sent_at: template.last_sent_at,
        scheduled_at: template.next_send_at
      )

      template.destroy
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
