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
      break if answer_acceptable?(result, context)

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

    acceptable = answer_acceptable?(result, context)
    Rails.logger.info(
      "[Captain DEBUG TMP] AutonomyPolicy: finished acceptable=#{acceptable} " \
      "escalating=#{!acceptable}"
    )
    record_trace_policy_check(
      name: 'autonomy_acceptance',
      passed: acceptable,
      reasoning_summary: acceptable ? 'Answer accepted by autonomy policy' : 'Answer rejected, escalating to human',
      inputs: {
        autonomy_retries_used: context[:autonomy_retry_count],
        knowledge_mode: @assistant.knowledge_mode,
        citation_status: context[:citation_verification_status]
      }
    )
    if acceptable
      result
    else
      record_trace_decision(
        :escalation_decision,
        domain: 'handoff', name: 'autonomy_max_retries',
        selected: true,
        reasoning_summary: 'Autonomy policy: escalation after max retries',
        inputs: { retries: context[:autonomy_retry_count] }
      )
      escalation_result(context)
    end
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

  def answer_acceptable?(result, context = {})
    output = result.output
    return false if output.blank?

    response_text = output.is_a?(Hash) ? (output['response'] || output[:response]).to_s : output.to_s

    if strict_knowledge_mode?
      faq_policy = extract_faq_policy(result)
      if faq_policy == 'no_match' && response_text != 'conversation_handoff'
        Rails.logger.info(
          '[Captain] AutonomyPolicy: rejecting answer - no_match policy ' \
          "in #{@assistant.knowledge_mode} mode"
        )
        return false
      end

      citation_status = Captain::Assistant::CitationValidator.check(
        assistant: @assistant, result: result, response_text: response_text
      )
      if citation_status != :ok
        Rails.logger.info("[Captain] AutonomyPolicy: rejecting answer — citations #{citation_status}")
        context[:citation_verification_status] = citation_status
        return false
      end

      unless verification_supported?(result, response_text, context)
        Rails.logger.info('[Captain] AutonomyPolicy: rejecting answer — LLM self-check unsupported')
        return false
      end
    end

    response_text.present?
  end

  SELF_CHECK_MIN_LENGTH = 40
  SELF_CHECK_CACHE_TTL = 24.hours

  def verification_supported?(result, response_text, context)
    return true unless self_check_enabled?
    return true if response_text == 'conversation_handoff'
    return true if Captain::Assistant::CitationValidator.clarifying_question?(response_text)
    return true if response_text.strip.length < SELF_CHECK_MIN_LENGTH

    lookup = Captain::Assistant::CitationValidator.extract_last_faq_lookup(result)
    return true if lookup.blank? || lookup[:policy].to_s != 'answer'

    sources = Array(lookup[:sources])
    return true if sources.empty?

    verdict = cached_verification(response_text, sources)
    return true unless verdict.is_a?(Hash) && verdict.key?(:supported)
    return true if verdict[:supported]

    context[:citation_verification_unsupported] = Array(verdict[:unsupported])
    false
  rescue StandardError => e
    Rails.logger.warn("[Captain] AnswerVerification failed open: #{e.class}: #{e.message}")
    true
  end

  def self_check_enabled?
    flag = @assistant.config['autonomy_self_check_enabled']
    return true if flag.nil? # default on for strict/ultra_strict

    ActiveModel::Type::Boolean.new.cast(flag)
  end

  def cached_verification(draft, sources)
    cache_key = "captain:answer_verification:#{Digest::SHA256.hexdigest([draft, sources.to_json].join('|'))}"
    cached = Rails.cache.read(cache_key)
    return cached if cached.is_a?(Hash) && cached.key?(:supported)

    verdict = Captain::Llm::AnswerVerificationService.new(
      account: @assistant.account, draft: draft, sources: sources
    ).perform
    Rails.cache.write(cache_key, verdict, expires_in: SELF_CHECK_CACHE_TTL)
    verdict
  end

  def strict_knowledge_mode?
    %w[strict ultra_strict].include?(@assistant.knowledge_mode)
  end

  def extract_faq_policy(result)
    return nil unless result.respond_to?(:context)

    last_lookup = result.context&.dig(:state, :orchestration, :last_faq_lookup)
    last_lookup&.dig(:policy) if last_lookup.is_a?(Hash)
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
      "faq_called=#{ctx&.dig(:captain_v2_faq_lookup_called)} " \
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
    unsupported = context[:citation_verification_unsupported]
    if unsupported.present?
      list = unsupported.first(5).map { |c| "- #{c}" }.join("\n")
      context[:citation_verification_unsupported] = nil
      return <<~HINT.strip
        Self-check rejected your previous draft because the following claims were not supported by the FAQ sources:
        #{list}
        Rewrite the answer using ONLY facts that are explicitly present in the source content. Add `[n]` citations after each factual sentence. If you cannot support a claim with a source, remove it. If nothing remains, escalate to a human.
      HINT
    end

    case attempt
    when 1
      if context[:captain_v2_faq_lookup_hit]
        'You already called captain--tools--faq_lookup and received results. If the policy is answer, use the answer_draft in your response. ' \
          'Each factual sentence MUST end with a citation marker [n] where n is the label of a source from the tool result. ' \
          'Do not invent labels. Do not include sentences that are not supported by any source. ' \
          'Do not set response to conversation_handoff when you have FAQ content to share.'
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
        'Try a different approach. If you need operator help or the issue requires human judgment, ' \
          'use escalate_to_human to transfer the conversation to a human agent.'
      end
    else
      'If you still cannot help, use escalate_to_human to transfer the conversation to a human agent.'
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
    if state['pending_customer_confirm'].present?
      context[:pending_customer_confirm] = state['pending_customer_confirm']
      context[:pending_customer_confirm_args_json] = state['pending_customer_confirm']['on_confirm_args'].to_json
    end
    enrich_context_with_contact_memory!(context)
    Captain::ScenarioResumeService.new(@conversation, state).enrich_context(context)
  end

  def enrich_context_with_contact_memory!(context)
    memory = @conversation&.contact&.additional_attributes&.dig('captain_memory')
    return if memory.blank?

    context[:contact_memory] = memory
    context[:contact_memory_json] = memory.to_json
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
