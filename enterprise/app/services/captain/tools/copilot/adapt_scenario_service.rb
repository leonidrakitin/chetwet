class Captain::Tools::Copilot::AdaptScenarioService < Captain::Tools::BaseTool
  description 'Adapt a scenario instruction to better fit the business context. Takes a scenario ID and customizes the instruction based on the business type and description.'

  param :scenario_id, type: :number, desc: 'The ID of the scenario to adapt', required: true
  param :adaptation_hints, type: :object, desc: 'Optional hints for adaptation (e.g., specific workflows, tools to use)', required: false

  def execute(scenario_id:, adaptation_hints: {})
    business_context = @assistant.account.settings['business_context']

    return { error: 'No business context set. Please configure business context in Account Settings first.' }.to_json if business_context.blank?

    scenario = Captain::Scenario.find_by(id: scenario_id, account_id: @assistant.account_id)

    return { error: "Scenario with ID #{scenario_id} not found" }.to_json if scenario.nil?

    adapted = adapt_scenario(scenario, business_context, adaptation_hints)

    {
      original: {
        id: scenario.id,
        title: scenario.title,
        instruction: scenario.instruction
      },
      adapted: adapted,
      message: 'Scenario instruction adapted. To apply changes, update the scenario in the Captain Assistant settings.'
    }.to_json
  end

  def active?
    user_has_permission('administrator')
  end

  private

  def adapt_scenario(scenario, business_context, hints)
    business_context['business_type']
    description = business_context['description']

    adapted_instruction = scenario.instruction.dup

    adapted_instruction = adapt_for_business(adapted_instruction, description) if description.present?

    adapted_instruction = add_workflows(adapted_instruction, hints['workflows']) if hints['workflows'].present?

    adapted_instruction = add_tool_references(adapted_instruction, hints['tools']) if hints['tools'].present?

    {
      title: scenario.title,
      instruction: adapted_instruction
    }
  end

  def adapt_for_business(instruction, business_description)
    instruction.gsub(/\[Salon name\]|\[business name\]|\[company name\]/i, business_description)
               .gsub(/\[product name\]/i, business_description)
  end

  def add_workflows(instruction, workflows)
    workflow_text = "\n\nAdditional workflows:\n#{workflows.map { |w| "- #{w}" }.join("\n")}"
    instruction + workflow_text
  end

  def add_tool_references(instruction, tools)
    tools.each do |tool|
      tool_ref = "[@#{tool}](tool://#{tool.parameterize(separator: '_')})"
      instruction += "\n- Use #{tool_ref} when appropriate."
    end
    instruction
  end
end
