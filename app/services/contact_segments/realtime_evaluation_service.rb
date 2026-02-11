class ContactSegments::RealtimeEvaluationService
  def initialize(contact:, trigger_source:, changed_attributes: {})
    @contact = contact
    @trigger_source = trigger_source
    @changed_attributes = changed_attributes
  end

  def call
    affected_segments = find_affected_segments
    affected_segments.each do |segment|
      reason = build_reason(@changed_attributes)
      ContactSegments::MembershipEvaluationService.new(
        segment: segment,
        trigger_source: @trigger_source,
        reason: reason,
        contact_ids: [@contact.id]
      ).call
    end
  end

  private

  def find_affected_segments
    @contact.account.contact_segments.active.where(triggers_enabled: true)
  end

  def build_reason(changed_attributes)
    return nil if changed_attributes.blank?

    changed_keys = changed_attributes.keys.join(', ')
    "Attributes changed: #{changed_keys}"
  end
end
