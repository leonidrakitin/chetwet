class Campaigns::DispatchService
  pattr_initialize [:campaign!]

  def call
    target_conversations.each do |conversation|
      Campaigns::MessageSenderService.new(campaign: campaign, conversation: conversation).call
    end
    campaign.update!(last_sent_at: Time.current, enabled: false)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
    campaign.update!(metadata: campaign.metadata.merge('last_error' => e.message))
    raise
  end

  private

  def target_conversations
    Campaigns::AudienceScope.new(campaign: campaign).call
  end
end
