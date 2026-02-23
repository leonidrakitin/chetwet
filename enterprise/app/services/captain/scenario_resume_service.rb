class Captain::ScenarioResumeService
  def initialize(conversation, runtime_state)
    @conversation = conversation
    @state = runtime_state
  end

  def enrich_context(context)
    scenario_id = @state['current_scenario_id']
    return unless scenario_id.present? && @state['autonomy_return_to_scenario']

    context[:resume_scenario] = { scenario_id: scenario_id, last_step: @state['scenario_step'] }.compact
  end
end
