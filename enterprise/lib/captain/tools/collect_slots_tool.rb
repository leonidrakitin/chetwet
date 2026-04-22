# frozen_string_literal: true

# Scenario-scoped tool that tracks required slots a scenario needs before invoking
# any write/critical tool. The scenario defines its slots via `required_slots`
# (jsonb: [{name, prompt, source_tool}]); this tool reads/updates collected values
# on `state.orchestration.collected_slots` and reports missing ones back to the LLM.
class Captain::Tools::CollectSlotsTool < Captain::Tools::BasePublicTool
  risk_level :read

  description 'Check which required parameters (slots) the scenario still needs before calling write/critical tools. ' \
              'Optionally record newly collected values via `updates`. Returns missing slots and a hint to ask the user.'
  param :updates, type: 'object',
                  desc: 'Optional hash of slot_name => value to record as collected (e.g. {"service_id": "42"})',
                  required: false

  def initialize(assistant, scenario: nil)
    @scenario = scenario
    super(assistant)
  end

  def name
    'collect_slots'
  end

  def perform(tool_context, updates: nil)
    slots = required_slots
    return { status: 'noop', missing: [], collected: {}, hint: 'No required slots defined.' } if slots.blank?

    collected = apply_updates(tool_context, updates)
    missing = slots.filter_map { |slot| missing_entry(slot, collected) }

    { status: missing.empty? ? 'complete' : 'incomplete', collected: collected.to_h, missing: missing, hint: hint_for(missing) }
  end

  private

  def apply_updates(tool_context, updates)
    orchestration = (tool_context.state[:orchestration] ||= {})
    collected = (orchestration[:collected_slots] ||= {}).with_indifferent_access

    if updates.is_a?(Hash)
      updates.each { |k, v| collected[k.to_s] = v }
      orchestration[:collected_slots] = collected.to_h
    end
    collected
  end

  def hint_for(missing)
    return 'All required slots collected. You may proceed with write/critical tools.' if missing.empty?

    'Ask the user for the missing slots (or call the listed source_tool) before any write/critical tool.'
  end

  def required_slots
    slots = @scenario&.required_slots
    return [] if slots.blank?

    Array(slots).map { |slot| slot.is_a?(Hash) ? slot.with_indifferent_access : {} }
  end

  def missing_entry(slot, collected)
    name = slot[:name].to_s
    return nil if name.blank?
    return nil if collected[name].present?

    {
      name: name,
      prompt: slot[:prompt].to_s,
      source_tool: slot[:source_tool].to_s
    }.reject { |_, v| v.blank? }
  end
end
