module Captain::Assistant::AutonomyPolicyHelper
  private

  DEFAULT_AUTONOMY_MAX_RETRIES = 2

  def run_with_autonomy_policy(message, context)
    return runner.run(message, context: context, max_turns: 100) unless autonomy_enabled?

    max_retries = effective_autonomy_max_retries

    result = nil
    (max_retries + 1).times do |attempt|
      result = runner.run(message, context: context, max_turns: 100)
      context[:autonomy_retry_count] = attempt
      break if answer_acceptable?(result)

      append_retry_hint!(context, attempt + 1, message) if attempt < max_retries
    end

    answer_acceptable?(result) ? result : escalation_result(context)
  end

  # autonomy_max_retries: nil → default 2 (autonomy on)
  # autonomy_max_retries: 0  → simple mode: answer or handoff, no retries
  def effective_autonomy_max_retries
    val = @assistant.autonomy_max_retries
    val.nil? ? DEFAULT_AUTONOMY_MAX_RETRIES : val.to_i
  end

  def autonomy_enabled?
    effective_autonomy_max_retries.positive?
  end

  def answer_acceptable?(result)
    output = result.output
    return false if output.blank?

    response_text = output.is_a?(Hash) ? (output['response'] || output[:response]).to_s : output.to_s
    response_text.present? && response_text != 'conversation_handoff'
  end

  def append_retry_hint!(context, attempt, message = nil)
    hint = build_retry_hint(attempt, message, context)
    context[:conversation_history] ||= []
    context[:conversation_history] << { role: :system, content: hint }
  end

  def build_retry_hint(attempt, message, context)
    case attempt
    when 1
      if context[:captain_v2_faq_lookup_hit]
        'You already called captain--tools--faq_lookup and received results. You must reply to the user with that content. Put the answer text in the "response" field. Do not set response to conversation_handoff when you have FAQ content to share.'
      elsif context[:captain_v2_faq_lookup_called]
        context[:clarification_sent] = true
        'You already called captain--tools--faq_lookup, but it returned no relevant FAQs. Ask the user one short clarification question or rephrase the query and call captain--tools--faq_lookup again. Do not hand off to a human yet.'
      else
        context[:clarification_sent] = true
        'If you cannot find a confident answer, ask the user a short clarification question.'
      end
    when 2
      router = Captain::ScenarioRouterService.new(message.to_s, @assistant)
      if router.scenarios_available?
        context[:scenario_router_attempted] = true
        router.routing_hint
      else
        'Try a different approach. If you still cannot help, hand off to a human agent.'
      end
    else
      'If you still cannot help, hand off to a human agent.'
    end
  end

  def escalation_result(context)
    Struct.new(:output, :context).new(
      { 'response' => 'conversation_handoff', 'reasoning' => 'Autonomy policy: escalation after max retries' },
      context
    )
  end

  def enrich_context_with_runtime_state!(context)
    return unless @conversation

    state = Captain::RuntimeStateService.new(@conversation).state
    Captain::ScenarioResumeService.new(@conversation, state).enrich_context(context)
  end

  def track_faq_usage(tool_name, faq_tool_name, tool_result, context_wrapper)
    return unless context_wrapper&.context
    return unless tool_name.to_s == faq_tool_name

    context_wrapper.context[:captain_v2_faq_lookup_called] = true
    hit = faq_lookup_hit?(tool_result)
    context_wrapper.context[:captain_v2_faq_lookup_hit] = hit unless hit.nil?

    return unless tool_result.is_a?(Hash)

    root_span = context_wrapper.context.dig(:__otel_tracing, :root_span)
    return unless root_span

    record_faq_span_attributes(root_span, tool_result)
  end

  def faq_lookup_hit?(tool_result)
    case tool_result
    when Hash
      policy = tool_result.with_indifferent_access['policy']
      return true if policy.blank?

      policy.to_s != 'no_match'
    when String
      str = tool_result.strip
      return nil if str.blank?

      !str.match?(/\ANo (relevant )?FAQs found/i) && !str.match?(/\ANo FAQs found/i)
    end
  end

  def record_faq_span_attributes(root_span, tool_result)
    result = tool_result.with_indifferent_access
    confidence = result['confidence']
    policy = result['policy']

    root_span.set_attribute(format(ATTR_LANGFUSE_METADATA, 'faq_confidence'), confidence.to_s) if confidence
    root_span.set_attribute(format(ATTR_LANGFUSE_METADATA, 'faq_policy'), policy.to_s) if policy
    root_span.set_attribute(format(ATTR_LANGFUSE_METADATA, 'faq_hit'), (policy != 'no_match').to_s) if policy
  end
end
