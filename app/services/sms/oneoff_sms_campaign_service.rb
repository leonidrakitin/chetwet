class Sms::OneoffSmsCampaignService
  pattr_initialize [:campaign!]

  def perform
    raise "Invalid campaign #{campaign.id}" if campaign.inbox.inbox_type != 'Sms' || !campaign.one_off?
    raise 'Completed Campaign' if campaign.completed?

    # marks campaign completed so that other jobs won't pick it up
    campaign.completed!

    process_audience
  end

  private

  delegate :inbox, to: :campaign
  delegate :channel, to: :inbox

  def process_audience
    Campaigns::AudienceResolutionService.new(campaign: campaign).perform.each do |contact|
      next if contact.phone_number.blank?

      template_service = Liquid::CampaignTemplateService.new(campaign: campaign, contact: contact)
      campaign.campaign_messages.each do |content|
        rendered = template_service.call(content)
        next if rendered.blank?

        send_message(to: contact.phone_number, content: rendered)
      end
    end
  end

  def send_message(to:, content:)
    channel.send_text_message(to, content)
  rescue StandardError => e
    Rails.logger.error("[SMS Campaign #{campaign.id}] Failed to send to #{to}: #{e.message}")
  end
end
