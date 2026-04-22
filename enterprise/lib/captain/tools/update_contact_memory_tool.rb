# frozen_string_literal: true

# Writes structured long-term memory for the current contact.
# Sections are free-form; supported operations: `set` (merge/replace values) and
# `append` (push into a list-valued section).
class Captain::Tools::UpdateContactMemoryTool < Captain::Tools::BasePublicTool
  risk_level :write

  ALLOWED_SECTIONS = %w[preferences open_tasks past_orders notes].freeze

  description 'Record or update long-term structured memory for the current contact. ' \
              'Use only when the conversation produced a concrete new fact.'
  param :section, type: 'string',
                  desc: "Section to update. Allowed: #{ALLOWED_SECTIONS.join(', ')}"
  param :operation, type: 'string', desc: 'Operation: "set" (merge/replace) or "append" (add to list)'
  param :value, type: 'object', desc: 'Payload to write (hash for set, hash/string for append)'

  def perform(tool_context, section:, operation:, value:)
    error = validate!(section, operation, value)
    return { status: 'error', error: error } if error

    contact = find_contact(tool_context.state)
    return { status: 'error', error: 'No contact associated with this conversation' } unless contact

    attributes = contact.additional_attributes || {}
    memory = attributes.fetch('captain_memory', {})
    memory[section] = apply_operation(memory[section], operation, value)
    contact.update!(additional_attributes: attributes.merge('captain_memory' => memory))

    { status: 'ok', section: section, operation: operation, data: memory[section] }
  rescue ActiveRecord::RecordInvalid => e
    { status: 'error', error: "Failed to persist memory: #{e.message}" }
  end

  private

  def validate!(section, operation, value)
    return "section must be one of: #{ALLOWED_SECTIONS.join(', ')}" unless ALLOWED_SECTIONS.include?(section.to_s)
    return 'operation must be set or append' unless %w[set append].include?(operation.to_s)
    return 'value is required' if value.nil?

    nil
  end

  def apply_operation(existing, operation, value)
    case operation.to_s
    when 'set'
      merge_set(existing, value)
    when 'append'
      Array.wrap(existing) + [value]
    end
  end

  def merge_set(existing, value)
    return value unless existing.is_a?(Hash) && value.is_a?(Hash)

    existing.deep_merge(value)
  end
end
