# frozen_string_literal: true

# Returns the structured long-term memory for the current contact.
# Memory is stored under `contact.additional_attributes['captain_memory']`
# and organised by section (preferences, open_tasks, past_orders, etc.).
class Captain::Tools::GetContactMemoryTool < Captain::Tools::BasePublicTool
  risk_level :read

  description 'Fetch long-term structured memory for the current contact (preferences, open tasks, past orders).'
  param :section, type: 'string',
                  desc: 'Optional section name to fetch (e.g. preferences). Omit to return the entire memory.',
                  required: false

  def perform(tool_context, section: nil)
    contact = find_contact(tool_context.state)
    return { status: 'error', error: 'No contact associated with this conversation' } unless contact

    memory = (contact.additional_attributes || {}).fetch('captain_memory', {})
    return { status: 'ok', section: section, data: memory.fetch(section.to_s, nil) } if section.present?

    { status: 'ok', data: memory }
  end
end
