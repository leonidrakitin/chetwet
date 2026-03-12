class NotificationTemplates::AudienceScope
  pattr_initialize [:template!]

  def call
    scoped = template.account.conversations.includes(:contact, :inbox, :contact_inbox, :messages)
    scoped = scoped.where(inbox_id: template.effective_inbox_id) if template.effective_inbox_id.present?
    scoped = filter_by_yclients(scoped)
    scoped.order(updated_at: :desc)
          .select { |conversation| audience_match?(conversation) }
          .uniq { |conversation| [conversation.contact_id, conversation.inbox_id] }
  end

  private

  def filter_by_yclients(scope)
    return scope if template.yclients_integration.blank?

    scope.where(
      "(additional_attributes -> 'yclients' ->> 'company_id') = ?",
      template.yclients_integration.salon_id.to_s
    )
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def audience_match?(conversation)
    tags = Array.wrap(template.audience['tags']).map(&:to_s)
    exclude_tags = Array.wrap(template.audience['exclude_tags']).map(&:to_s)
    labels = Array.wrap(conversation.contact.label_list).map(&:to_s)

    tags_match = tags.blank? || (tags - labels).blank?
    exclude_match = exclude_tags.blank? || !exclude_tags.intersect?(labels)

    tags_match && exclude_match && yclients_conditions_match?(conversation)
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  # rubocop:disable Metrics/AbcSize
  def yclients_conditions_match?(conversation)
    return true if template.conditions.blank?

    yclients = conversation.additional_attributes['yclients'] || {}
    service_match = template.conditions['service_name'].blank? || yclients['service'].to_s.include?(template.conditions['service_name'].to_s)
    staff_match = template.conditions['staff_name'].blank? || yclients['staff'].to_s.include?(template.conditions['staff_name'].to_s)
    service_match && staff_match
  end
  # rubocop:enable Metrics/AbcSize
end
