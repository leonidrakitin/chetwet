class NotificationTemplates::ProcessScheduledJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    NotificationTemplate.active.find_each do |template|
      next unless should_dispatch?(template)

      NotificationTemplates::DispatchJob.perform_later(template.id, nil, scheduled_trigger_type(template))
      template.update!(next_send_at: next_send_at_for(template))
    end
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
end
