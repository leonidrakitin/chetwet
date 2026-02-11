class ContactSegments::RealtimeEvaluationJob < ApplicationJob
  queue_as :default

  def perform(contact_id:, trigger_source:, changed_attributes: {})
    contact = Contact.find_by(id: contact_id)
    return unless contact

    ContactSegments::RealtimeEvaluationService.new(
      contact: contact,
      trigger_source: trigger_source,
      changed_attributes: changed_attributes
    ).call
  end
end
