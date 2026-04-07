# rubocop:disable Metrics/ModuleLength, Metrics/MethodLength, Metrics/AbcSize, Layout/LineLength -- TEMP DEBUG TMP logging
module Captain::Assistant::AutonomyPolicyHelper
  private

  DEFAULT_AUTONOMY_MAX_RETRIES = 2

  def run_with_autonomy_policy(message, context)
    unless autonomy_enabled?
      Rails.logger.info('[Captain DEBUG TMP] AutonomyPolicy: disabled — single runner.run (max_turns=100)')
      result = runner.run(message, context: context, max_turns: 100)
      log_captain_debug_tmp_run_outcome(result, label: 'single_run')
      return result
    end

    max_retries = effective_autonomy_max_retries
    Rails.logger.info(
      '[Captain DEBUG TMP] AutonomyPolicy: enabled ' \
      "max_retries=#{max_retries} attempts=#{max_retries + 1}"
    )

    result = nil
    (max_retries + 1).times do |attempt|
      Rails.logger.info("[Captain DEBUG TMP] AutonomyPolicy: runner.run attempt=#{attempt} / #{max_retries}")
      result = runner.run(message, context: context, max_turns: 100)
      context[:autonomy_retry_count] = attempt
      log_captain_debug_tmp_run_outcome(result, label: "attempt_#{attempt}")
      break if answer_acceptable?(result)

      # Stop retrying if the runner itself errored (e.g. LLM API failure) — retries would be identical
      if result.respond_to?(:error) && result.error
        Rails.logger.error(
          "[Captain DEBUG TMP] AutonomyPolicy: runner error on attempt #{attempt}, " \
          "aborting retries: #{result.error.class}: #{result.error.message}"
        )
        break
      end

      append_retry_hint!(context, attempt + 1, message) if attempt < max_retries
    end

    acceptable = answer_acceptable?(result)
    Rails.logger.info(
      "[Captain DEBUG TMP] AutonomyPolicy: finished acceptable=#{acceptable} " \
      "escalating=#{!acceptable}"
    )
    acceptable ? result : escalation_result(context)
  end

  # autonomy_max_retries: nil → default 2 (autonomy on)
  # autonomy_max_retries: 0  → simple mode: answer or escalation, no retries
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

  def log_captain_debug_tmp_run_outcome(result, label:)
    output = result&.output
    text = output.is_a?(Hash) ? (output['response'] || output[:response]).to_s : output.to_s
    ctx = result.respond_to?(:context) ? result.context : nil
    error = result.respond_to?(:error) ? result.error : nil
    Rails.logger.info(
      '[Captain DEBUG TMP] runner.run outcome ' \
      "label=#{label} acceptable=#{answer_acceptable?(result)} " \
      "response_preview=#{text.truncate(400).inspect} " \
      "current_agent=#{ctx&.dig(:current_agent).inspect} " \
      "faq_called=#{ctx&.dig(:captain_v2_faq_lookup_called)} ask_human_called=#{ctx&.dig(:captain_v2_ask_human_called)} " \
      "error=#{error&.class}:#{error&.message&.truncate(500)}"
    )
  end

  def append_retry_hint!(context, attempt, message = nil)
    hint = build_retry_hint(attempt, message, context)
    context[:conversation_history] ||= []
    # NOTE: role must be :user because the Agents::Runner only restores user/assistant/tool messages.
    # System-role messages are silently dropped during conversation history restoration.
    context[:conversation_history] << { role: :user, content: "[SYSTEM INSTRUCTION] #{hint}" }
  end

  def build_retry_hint(attempt, message, context)
    case attempt
    when 1
      if context[:captain_v2_faq_lookup_hit]
        'You already called captain--tools--faq_lookup and received results. If the policy is answer, use the answer_draft in your response. Do not set response to conversation_handoff when you have FAQ content to share.'
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
        'Try a different approach. If you need operator approval or a background clarification, use captain--tools--ask_human. ' \
          'Only use captain--tools--escalate_to_human if the user explicitly asked for a human agent or the issue is completely ' \
          'outside your capabilities and cannot be addressed via ask_human.'
      end
    else
      'If you still cannot help, use captain--tools--ask_human when you need approval or operator input. ' \
      'Use captain--tools--escalate_to_human only as a last resort if the user explicitly demands a live agent or the problem ' \
      'is entirely unsolvable here.'
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
    pending_interaction = state['pending_human_interaction']
    if pending_interaction.present?
      context[:pending_human_interaction] = pending_interaction
      snapshot_count = pending_interaction.dig('snapshot', 'message_count').to_i
      context[:pending_human_interaction_stale] = snapshot_count.positive? && snapshot_count != @conversation.messages.count
    end
    context[:last_human_response] = state['last_human_response'] if state['last_human_response'].present?
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
# rubocop:enable Metrics/ModuleLength, Metrics/MethodLength, Metrics/AbcSize, Layout/LineLength
