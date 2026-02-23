module Captain::Assistant::AutonomyPolicyHelper
  private

  def run_with_autonomy_policy(message, context)
    max_retries = @assistant.autonomy_max_retries.to_i
    return runner.run(message, context: context, max_turns: 100) if max_retries.zero?

    result = nil
    (max_retries + 1).times do |attempt|
      result = runner.run(message, context: context, max_turns: 100)
      context[:autonomy_retry_count] = attempt
      break if answer_acceptable?(result)

      append_retry_hint!(context, attempt + 1) if attempt < max_retries
    end

    answer_acceptable?(result) ? result : escalation_result(context)
  end

  def answer_acceptable?(result)
    output = result.output
    return false if output.blank?

    response_text = output.is_a?(Hash) ? (output['response'] || output[:response]).to_s : output.to_s
    response_text.present? && response_text != 'conversation_handoff'
  end

  def append_retry_hint!(context, attempt)
    hint = case attempt
           when 1 then 'If you cannot find a confident answer, ask the user for clarification.'
           when 2 then 'Try a different approach or route to a relevant scenario. Ask for more information if needed.'
           else 'If you still cannot help, hand off to a human agent.'
           end
    context[:conversation_history] ||= []
    context[:conversation_history] << { role: :system, content: hint }
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
    return unless tool_name.to_s == faq_tool_name && tool_result.is_a?(Hash)

    root_span = context_wrapper&.context&.dig(:__otel_tracing, :root_span)
    return unless root_span

    record_faq_span_attributes(root_span, tool_result)
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
