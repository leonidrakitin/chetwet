class Campaigns::ProcessScheduledJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Campaign.due.find_each do |campaign|
      Campaigns::DispatchJob.perform_later(campaign.id)
    end
  end
end
