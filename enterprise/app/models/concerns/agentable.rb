module Concerns::Agentable
  extend ActiveSupport::Concern

  # `runtime_model` is the validated model resolved by Captain V2's runtime
  # path (Llm::Config.resolve_runtime_model). When passed in we use it as
  # source-of-truth for both the primary agent and any orchestration sub-agents,
  # so the whole tree stays consistent with the runtime provider.
  def agent(runtime_model: nil)
    Agents::Agent.new(
      name: agent_name,
      instructions: ->(context) { agent_instructions(context) },
      tools: agent_tools(runtime_model: runtime_model),
      model: agent_model(runtime_model: runtime_model),
      temperature: temperature.to_f || 0.7,
      response_schema: agent_response_schema
    )
  end

  def agent_instructions(context = nil)
    enhanced_context = prompt_context

    if context
      state = context.context[:state] || {}
      config = state[:assistant_config] || {}
      enhanced_context = enhanced_context.merge(
        conversation: state[:conversation] || {},
        contact: config['feature_contact_attributes'].present? ? state[:contact] : nil,
        orchestration_state: state[:orchestration] || {},
        orchestration_state_json: (state[:orchestration] || {}).to_json,
        handoff_summary: context.context.dig(:last_handoff, :summary),
        handoff_reason: context.context.dig(:last_handoff, :reason),
        detected_language: state[:detected_language]
      )
      enhanced_context[:conversation_length] = context.context[:conversation_length] if context.context.key?(:conversation_length)
      enhanced_context[:routing_hint] = context.context[:routing_hint] if context.context.key?(:routing_hint)
      enhanced_context[:routing_plan] = context.context[:routing_plan] if context.context.key?(:routing_plan)
      enhanced_context[:routing_plan_json] = context.context[:routing_plan].to_json if context.context.key?(:routing_plan)
      if context.context[:pending_customer_confirm].present?
        enhanced_context[:pending_customer_confirm] = context.context[:pending_customer_confirm]
        enhanced_context[:pending_customer_confirm_args_json] =
          context.context[:pending_customer_confirm_args_json] || context.context[:pending_customer_confirm]['on_confirm_args'].to_json
      end
      if context.context[:contact_memory].present?
        enhanced_context[:contact_memory] = context.context[:contact_memory]
        enhanced_context[:contact_memory_json] = context.context[:contact_memory_json] || context.context[:contact_memory].to_json
      end
    end

    [
      Agents::RECOMMENDED_HANDOFF_PROMPT_PREFIX,
      Captain::PromptRenderer.render(template_name, enhanced_context.with_indifferent_access)
    ].join("\n")
  end

  private

  def agent_name
    raise NotImplementedError, "#{self.class} must implement agent_name"
  end

  def template_name
    self.class.name.demodulize.underscore
  end

  def agent_tools(runtime_model: nil) # rubocop:disable Lint/UnusedMethodArgument
    []  # Default implementation, override if needed
  end

  # Captain V2 runtime path passes the validated runtime_model. We deliberately
  # do not consult CAPTAIN_OPEN_AI_MODEL here — that legacy installation config
  # is provider-agnostic and would silently route an openrouter run through
  # an OpenAI-shaped model name. Legacy non-runtime callers fall back to
  # LlmConstants::DEFAULT_MODEL.
  def agent_model(runtime_model: nil)
    runtime_model.presence || LlmConstants::DEFAULT_MODEL
  end

  def agent_response_schema
    Captain::ResponseSchema
  end

  def orchestration_subagent_tools(runtime_model: nil)
    return [] unless orchestration_subagents_enabled?

    [planner_agent_tool(runtime_model: runtime_model), policy_agent_tool(runtime_model: runtime_model)]
  end

  def orchestration_subagents_enabled?
    config = if respond_to?(:config)
               self.config
             elsif respond_to?(:assistant)
               assistant&.config
             end
    return true if config.blank? || !config.key?('autonomy_self_check_enabled')

    ActiveModel::Type::Boolean.new.cast(config['autonomy_self_check_enabled'])
  end

  def prompt_context
    raise NotImplementedError, "#{self.class} must implement prompt_context"
  end

  def planner_agent_tool(runtime_model: nil)
    Agents::Agent.new(
      name: "#{agent_name}_planner",
      instructions: lambda { |_context|
        'You are a planning sub-agent. Decide the safest next action for the current customer turn. ' \
          'Prefer one of: faq_lookup, scenario handoff, clarification question, or escalate_to_human. ' \
          'MUST escalate for restricted actions: cancellations, refunds, or account changes. ' \
          'Keep your reasoning concise and return only structured output.'
      },
      model: orchestration_subagent_model(runtime_model: runtime_model),
      temperature: 0.2,
      response_schema: planner_response_schema
    ).as_tool(
      name: 'plan_next_step',
      description: 'Plan the next orchestration step with route, confidence, and a compact transfer summary if needed'
    )
  end

  def policy_agent_tool(runtime_model: nil)
    Agents::Agent.new(
      name: "#{agent_name}_policy",
      instructions: lambda { |_context|
        'You are a policy sub-agent. Review whether the assistant should reply directly ' \
          'or escalate to a human agent. Return only structured output. ' \
          'CRITICAL: You MUST escalate to a human (action: escalate_to_human, safe_to_reply: false) ' \
          'for restricted actions: cancellations, refunds, or account changes. ' \
          'Even if the request looks simple, if it involves these topics, escalation is mandatory.'
      },
      model: orchestration_subagent_model(runtime_model: runtime_model),
      temperature: 0.1,
      response_schema: policy_response_schema
    ).as_tool(
      name: 'check_response_policy',
      description: 'Validate whether to reply directly or escalate to human support'
    )
  end

  def orchestration_subagent_model(runtime_model: nil)
    runtime_model.presence || LlmConstants::DEFAULT_MODEL
  end

  def planner_response_schema
    {
      type: 'object',
      properties: {
        route: {
          type: 'string',
          enum: %w[faq scenario direct clarify escalate_to_human]
        },
        confidence: { type: 'number' },
        rationale: { type: 'string' },
        suggested_tool: { type: 'string' },
        handoff_reason: { type: 'string' },
        transfer_summary: { type: 'string' }
      },
      required: %w[route confidence rationale],
      additionalProperties: false
    }
  end

  def policy_response_schema
    {
      type: 'object',
      properties: {
        action: {
          type: 'string',
          enum: %w[reply escalate_to_human]
        },
        confidence: { type: 'number' },
        rationale: { type: 'string' },
        safe_to_reply: { type: 'boolean' }
      },
      required: %w[action confidence rationale safe_to_reply],
      additionalProperties: false
    }
  end
end
