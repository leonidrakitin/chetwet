class Twilio::OneoffSmsCampaignService
  pattr_initialize [:campaign!]

  def perform
    raise "Invalid campaign #{campaign.id}" if campaign.inbox.inbox_type != 'Twilio SMS' || !campaign.one_off?
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

        begin
          channel.send_message(to: contact.phone_number, body: rendered)
        rescue Twilio::REST::TwilioError, Twilio::REST::RestError => e
          Rails.logger.error("[Twilio Campaign #{campaign.id}] Failed to send to #{contact.phone_number}: #{e.message}")
          break
        end
      end
    end
  end
end
