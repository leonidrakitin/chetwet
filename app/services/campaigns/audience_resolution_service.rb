class Campaigns::AudienceResolutionService
  pattr_initialize [:campaign!]

  def perform
    if campaign.segment_id.present?
      resolve_from_segment
    else
      resolve_from_labels
    end
  end

  private

  def resolve_from_segment
    segment = campaign.account.contact_segments.find(campaign.segment_id)
    result = ::Contacts::NestedFilterService.new(campaign.account, segment.query).perform
    result[:contacts]
  end

  def resolve_from_labels
    audience_labels = extract_audience_labels
    campaign.account.contacts.tagged_with(audience_labels, any: true)
  end

  def extract_audience_labels
    audience_label_ids = campaign.audience.select { |audience| audience['type'] == 'Label' }.pluck('id')
    campaign.account.labels.where(id: audience_label_ids).pluck(:title)
  end
end
