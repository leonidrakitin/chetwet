class Campaigns::AudienceScope
  pattr_initialize [:campaign!]

  def call
    use_cascade? ? cascade_scope : standard_scope
  end

  private

  def standard_scope
    scoped = campaign.account.conversations.includes(:contact, :inbox, :contact_inbox, :messages)
    scoped = scoped.where(inbox_id: campaign.inbox_id) if campaign.inbox_id.present?
    scoped = scoped.where(contact_id: segment_contact_ids) if segment_contact_ids.present?
    scoped.order(updated_at: :desc)
          .select { |conversation| audience_match?(conversation) }
          .uniq { |conversation| [conversation.contact_id, conversation.inbox_id] }
  end

  def use_cascade?
    campaign.inbox_id.blank? && cascade_chain.any?
  end

  def cascade_chain
    chain_key = campaign.audience['require_mailing_consent'] ? 'marketing' : 'service'
    Array.wrap(campaign.account.cascade_settings&.dig(chain_key)).map(&:to_i).reject(&:zero?)
  end

  def cascade_scope
    all_matching = campaign.account.conversations
                           .includes(:contact, :inbox, :contact_inbox, :messages)
                           .where(inbox_id: cascade_chain)
                           .select { |c| audience_match?(c) }
    cascade_order = cascade_chain.each_with_index.to_h
    all_matching
      .group_by(&:contact_id)
      .values
      .map { |convos| convos.min_by { |c| cascade_order[c.inbox_id] || 999 } }
  end

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

  def audience_match?(conversation)
    tags = Array.wrap(campaign.audience['tags']).map(&:to_s)
    exclude_tags = Array.wrap(campaign.audience['exclude_tags']).map(&:to_s)
    labels = Array.wrap(conversation.contact.label_list).map(&:to_s)

    tags_match = tags.blank? || (tags - labels).blank?
    exclude_match = exclude_tags.blank? || !exclude_tags.intersect?(labels)

    tags_match && exclude_match
  end
end
