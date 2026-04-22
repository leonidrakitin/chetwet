class NotificationTemplates::ProcessScheduledJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    NotificationTemplate.active.find_each do |template|
      next unless should_dispatch?(template)

      NotificationTemplates::DispatchJob.perform_later(template.id, nil, scheduled_trigger_type(template))
      template.update!(next_send_at: next_send_at_for(template))
    end

    process_due_scheduled_deliveries
  end

  private

  def should_dispatch?(template)
    template.next_send_at.present? && template.next_send_at <= Time.current
  end

  def next_send_at_for(template)
    NotificationTemplates::ScheduleCalculator.new(template: template).next_time(from_time: 1.second.from_now)
  end

  def scheduled_trigger_type(template)
    template.interval_template? ? 'interval' : 'time'
  end

  def process_due_scheduled_deliveries
    NotificationTemplateDelivery.due_scheduled.includes(:notification_template, :conversation, :contact).find_each do |delivery|
      dispatch_or_reschedule(delivery)
    end
  end

  def dispatch_or_reschedule(delivery)
    template = delivery.notification_template
    conversation = delivery.conversation
    contact = delivery.contact
    return drop(delivery, 'missing_context') if template.blank? || conversation.blank? || contact.blank?

    eligibility = NotificationTemplates::EligibilityService.new(template: template, conversation: conversation).call

    if eligibility[:ok]
      trigger_type = delivery.trigger_type
      delivery.destroy!
      NotificationTemplates::MessageSenderService.new(template: template, conversation: conversation, trigger_type: trigger_type).call
    elsif NotificationTemplates::DispatchService::RESCHEDULABLE_REASONS.include?(eligibility[:reason])
      new_time = NotificationTemplates::SchedulerService.new(
        template: template, contact: contact, account: template.account, reason: eligibility[:reason]
      ).call
      delivery.update!(scheduled_for: new_time, metadata: delivery.metadata.merge('reason' => eligibility[:reason]))
    else
      drop(delivery, eligibility[:reason])
    end
  end

  def drop(delivery, reason)
    delivery.update!(status: 'skipped', sent_at: Time.current,
                     metadata: delivery.metadata.merge('dropped_reason' => reason))
  end
end
