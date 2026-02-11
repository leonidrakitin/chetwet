class SegmentListener < BaseListener
  def message_created(event)
    message = event.data[:message]
    return unless message

    contact = message.conversation&.contact
    return unless contact

    trigger_source = if message.incoming?
                       'inbound_message'
                     else
                       'outbound_campaign'
                     end

    ContactSegments::RealtimeEvaluationJob.perform_later(
      contact_id: contact.id,
      trigger_source: trigger_source
    )
  end

  def contact_updated(event)
    contact = event.data[:contact]
    changed_attributes = event.data[:changed_attributes] || {}
    return unless contact

    ContactSegments::RealtimeEvaluationJob.perform_later(
      contact_id: contact.id,
      trigger_source: 'manual_edit',
      changed_attributes: changed_attributes
    )
  end
end
