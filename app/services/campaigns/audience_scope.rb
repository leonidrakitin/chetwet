def segment_contact_ids
  return @segment_contact_ids if defined?(@segment_contact_ids)

  segment_id = campaign.audience['segment_id']
  return @segment_contact_ids = nil if segment_id.blank?

  custom_filter = campaign.account.custom_filters.find_by(id: segment_id, filter_type: :contact)
  return @segment_contact_ids = nil if custom_filter.blank?

  result = Contacts::FilterService.new(
    campaign.account, nil, { payload: custom_filter.query }
  ).perform
  @segment_contact_ids = result[:contacts].pluck(:id)
end
