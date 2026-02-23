class Captain::ScenarioRouterService
  def initialize(message, assistant)
    @message = message.to_s
    @assistant = assistant
  end

  # Returns a routing hint string for the agent that lists available scenarios.
  # No LLM call — the agent framework (handoffs) handles the actual routing.
  def routing_hint
    enabled_scenarios = @assistant.scenarios.enabled.to_a
    return nil if enabled_scenarios.empty?

    names = enabled_scenarios.map(&:title).join(', ')
    "Available scenarios: #{names}. Route to the most relevant one if the query matches, otherwise ask for clarification."
  end

  # Returns true if there are enabled scenarios to potentially route to.
  def scenarios_available?
    @assistant.scenarios.enabled.exists?
  end
end
