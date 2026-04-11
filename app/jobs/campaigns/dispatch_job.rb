class Campaigns::DispatchJob < ApplicationJob
  queue_as :high

  def perform(campaign_id)
    campaign = Campaign.find(campaign_id)

    Campaigns::DispatchService.new(campaign: campaign).call
  end
end
