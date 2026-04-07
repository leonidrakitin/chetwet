class Captain::ScenarioRouterService
  def initialize(message, assistant)
    @message = message.to_s
    @assistant = assistant
  end

  # Returns a routing hint string for the agent that lists available scenarios.
  # No LLM call — the agent framework (handoffs) handles the actual routing.
  def routing_hint
    plan = routing_plan
    return plan[:hint] if plan[:hint].present?

    enabled_scenarios = @assistant.scenarios.enabled.to_a
    return nil if enabled_scenarios.empty?

    names = enabled_scenarios.map(&:title).join(', ')
    "Available scenarios: #{names}. Route to the most relevant one if the query matches, otherwise ask for clarification."
  end

  def routing_plan
    enabled_scenarios = @assistant.scenarios.enabled.to_a
    return { route: 'direct', confidence: 0.0, hint: nil } if enabled_scenarios.empty?

    match = enabled_scenarios.find do |scenario|
      tokens_for(scenario).any? { |token| @message.downcase.include?(token) }
    end

    if match
      {
        route: 'scenario',
        confidence: 0.9,
        scenario_id: match.id,
        scenario_key: match.handoff_key,
        hint: "Strong routing candidate: #{match.title}. Prefer handoff_to_#{match.handoff_key} unless the user is asking a pure FAQ question."
      }
    else
      {
        route: 'direct',
        confidence: 0.2,
        hint: 'No strong scenario match detected. Prefer FAQ lookup or a short clarification question before routing.'
      }
    end
  end

  # Returns true if there are enabled scenarios to potentially route to.
  def scenarios_available?
    @assistant.scenarios.enabled.exists?
  end

  private

  def tokens_for(scenario)
    [scenario.title, scenario.description].compact.flat_map do |text|
      text.to_s.downcase.scan(/[[:alnum:]_]{4,}/)
    end.uniq
  end
end
