require 'agents'
require 'agents/instrumentation'

# rubocop:disable Metrics/ClassLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength -- TEMP DEBUG TMP
class Captain::Assistant::AgentRunnerService
  include Integrations::LlmInstrumentationConstants
  include Captain::Assistant::RunnerCallbacksHelper
  include Captain::Assistant::TracePayloadHelper
  include Captain::Assistant::LlmPromptLogHelper
  include Captain::Assistant::AutonomyPolicyHelper

  CONVERSATION_STATE_ATTRIBUTES = %i[
    id display_id inbox_id contact_id priority
    label_list custom_attributes additional_attributes
  ].freeze

  CONTACT_STATE_ATTRIBUTES = %i[
    id name email phone_number identifier contact_type
    custom_attributes additional_attributes
  ].freeze

  CONTACT_INBOX_STATE_ATTRIBUTES = %i[id hmac_verified].freeze

  # `provider` / `model` are runtime overrides for the Captain V2 LLM call.
  # Both are optional from the caller's perspective: when not passed we resolve
  # `provider` from the primary chatwoot provider in CAPTAIN_PROVIDERS, and
  # `model` from Llm::Config.resolve_runtime_model. The runtime path itself
  # treats provider as mandatory — a blank resolution raises ProviderRequiredError
  # instead of silently falling through to the previous global-default-model
  # behaviour, which routed unprefixed model names through OpenAI even when
  # primary=openrouter.
  def initialize(assistant:, conversation: nil, callbacks: {}, source: nil, trace_recorder: nil, provider: nil, model: nil) # rubocop:disable Metrics/ParameterLists
    @assistant = assistant
    @conversation = conversation
    @callbacks = callbacks
    @source = source
    @trace_recorder = trace_recorder
    @runtime_provider = provider
    @runtime_model = model
  end

  def generate_response(message_history: [])
    message_to_process, context = run_payload(message_history)
    Rails.logger.info(
      '[Captain DEBUG TMP] AgentRunnerService#generate_response start ' \
      "assistant_id=#{@assistant.id} conversation_id=#{@conversation&.id} source=#{@source.inspect}"
    )

    # ai-agents' Runner uses the global RubyLLM/Agents config (no per-call context).
    # Re-apply the resolved runtime provider here so changes saved via Super Admin
    # take effect without an app restart, and so OpenAI-compatible providers
    # (deepseek/qwen/zai) populate openai_api_key/base correctly. We deliberately
    # apply for the runtime-resolved provider (not unconditionally the primary)
    # so a future runtime override stays consistent end-to-end.
    resolve_runtime_llm_selection!
    Llm::Config.apply_to_globals!(@resolved_provider)
    Llm::Config.validate_provider!(@resolved_provider)

    with_conversation_lock do
      result = run_with_autonomy_policy(message_to_process, context)
      process_agent_result(result)
    end
  rescue Llm::Config::ProviderNotConfiguredError,
         Llm::Config::ProviderRequiredError,
         Llm::Config::ModelNotAvailableForProviderError => e
    log_infra_error(e)
    infra_error_response(e)
  rescue StandardError => e
    # In rake/local runs, conversation may not be present, so account is optional here.
    ChatwootExceptionTracker.new(e, account: @conversation&.account).capture_exception
    if infra_error?(e)
      log_infra_error(e)
      return infra_error_response(e)
    end

    Rails.logger.error "[Captain V2] AgentRunnerService error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    error_response(e.message)
  end

  private

  def build_context(message_history)
    conversation_history = message_history.map do |msg|
      content = msg[:content]
      # Preserve multimodal arrays (with image_url entries) as-is for the runner to restore with attachments.
      # Only extract text from non-array formats (hashes from agent structured output, plain strings).
      content = extract_text_from_content(content) unless content.is_a?(Array)

      {
        role: msg[:role].to_sym,
        content: content,
        agent_name: msg[:agent_name]
      }
    end

    {
      session_id: "#{@assistant.account_id}_#{@conversation&.display_id}",
      conversation_history: conversation_history,
      state: build_state
    }
  end

  def extract_last_user_message(message_history)
    last_user_msg = message_history.reverse.find { |msg| msg[:role] == 'user' }
    return '' if last_user_msg.blank?

    content = last_user_msg[:content]
    return extract_text_from_content(content) unless content.is_a?(Array)

    text, attachments = Captain::OpenAiMessageBuilderService.extract_text_and_attachments(content)
    return text if attachments.blank?

    RubyLLM::Content.new(text, attachments)
  end

  def message_history_without_last_user_message(message_history)
    last_user_index = message_history.rindex { |msg| msg[:role] == 'user' }
    return message_history if last_user_index.nil?

    message_history.reject.with_index { |_msg, index| index == last_user_index }
  end

  def extract_text_from_content(content)
    # Handle structured output from agents
    return content[:response] || content['response'] || content[:answer_draft] || content['answer_draft'] || content.to_s if content.is_a?(Hash)

    return content unless content.is_a?(Array)

    text_parts = content.select { |part| part[:type] == 'text' }.pluck(:text)
    text_parts.join(' ')
  end

  def process_agent_result(result)
    Rails.logger.info "[Captain V2] Agent result: #{result.inspect}"
    output = result.output
    response = output.is_a?(Hash) ? output.with_indifferent_access : { 'response' => output.to_s, 'reasoning' => 'Processed by agent' }
    response['agent_name'] = result.context&.dig(:current_agent)
    response['response'] = normalize_repeated_response_text(response['response'])
    enforce_citation_grounding!(response, result)
    ensure_structural_handoff_invoked!(response, result)
    response.delete('_escalation_handled')
    text = response['response'].to_s
    Rails.logger.info(
      '[Captain DEBUG TMP] process_agent_result ' \
      "current_agent=#{result.context&.dig(:current_agent).inspect} " \
      "response_preview=#{text.truncate(400).inspect} " \
      "faq_lookup_called=#{result.context&.dig(:captain_v2_faq_lookup_called)}"
    )
    response
  end

  def enforce_citation_grounding!(response, result)
    return unless @assistant
    return if response['_escalation_handled']

    status = Captain::Assistant::CitationValidator.check(
      assistant: @assistant,
      result: result,
      response_text: response['response']
    )
    record_trace_citation_check(status, response['response'])
    return if status == :ok

    Rails.logger.info("[Captain] Citation grounding failed: #{status}")
    response['reasoning'] = "Citation grounding failed: #{status}. Original: #{response['reasoning']}"
    response['response'] = 'conversation_handoff'
    record_trace_decision(
      :escalation_decision,
      domain: 'handoff', name: 'citation_grounding_failed',
      selected: true,
      reasoning_summary: "Citation grounding failed: #{status}"
    )
    invoke_handoff_tool_fallback(response, source: 'citation_grounding')
    response['_escalation_handled'] = true
  end

  def normalize_repeated_response_text(raw_text)
    text = raw_text.to_s
    return text if text.blank?

    stripped = text.strip
    collapsed = collapse_exact_repeated_halves(stripped)
    return collapsed unless collapsed == stripped

    collapse_repeated_phrase_with_space(stripped)
  end

  def collapse_exact_repeated_halves(text)
    return text unless text.length.even?

    half_length = text.length / 2
    first_half = text[0...half_length]
    second_half = text[half_length..]
    first_half == second_half ? first_half : text
  end

  def collapse_repeated_phrase_with_space(text)
    match = text.match(/\A(.+?)\s+\1\z/m)
    match ? match[1] : text
  end

  # Structural fallback: if the synthetic post-retries handoff (or any other
  # path that sets response == 'conversation_handoff') was reached without the
  # escalate_to_human tool actually being invoked, run the handoff tool now so
  # the operator gets notified. Lexical detection has moved to the self-check
  # stage in AutonomyPolicyHelper.
  def ensure_structural_handoff_invoked!(response, result)
    return if response['_escalation_handled']
    return unless response['response'].to_s == 'conversation_handoff'
    return if result.respond_to?(:context) && result.context&.dig(:captain_v2_handoff_tool_called)

    record_trace_decision(
      :escalation_decision,
      domain: 'handoff', name: 'autonomy_max_retries_fallback',
      selected: true,
      reasoning_summary: 'Synthetic handoff after autonomy retries — invoking tool fallback'
    )
    invoke_handoff_tool_fallback(response, source: 'autonomy_max_retries')
    response['_escalation_handled'] = true
  end

  def record_trace_decision(event_type, **)
    return unless @trace_recorder.respond_to?(:record_decision)
    return unless @trace_recorder.enabled?

    @trace_recorder.record_decision(event_type, **)
  rescue StandardError => e
    Rails.logger.warn("[Captain::Trace] decision capture failed: #{e.message}")
  end

  def record_trace_citation_check(status, response_text)
    return unless @trace_recorder.respond_to?(:record)
    return unless @trace_recorder.enabled?

    @trace_recorder.record(:citation_check, {
                             status: status.to_s,
                             response_preview: response_text.to_s.truncate(200)
                           })
  rescue StandardError => e
    Rails.logger.warn("[Captain::Trace] citation_check capture failed: #{e.message}")
  end

  def record_trace_policy_check(name:, passed:, reasoning_summary: nil, inputs: nil)
    return unless @trace_recorder.respond_to?(:record)
    return unless @trace_recorder.enabled?

    @trace_recorder.record(:policy_check, {
      name: name.to_s,
      passed: passed,
      reasoning_summary: reasoning_summary,
      inputs: inputs
    }.compact)
  rescue StandardError => e
    Rails.logger.warn("[Captain::Trace] policy_check capture failed: #{e.message}")
  end

  def invoke_handoff_tool_fallback(response, source: nil)
    return unless @conversation

    reason = response['reasoning'].to_s.truncate(500).presence ||
             'Auto-escalation: LLM signaled escalation without calling tool'
    tool = Captain::Tools::HandoffTool.new(@assistant)
    tool_context = build_fallback_tool_context
    correlation_id = record_fallback_handoff_tool_start(tool, reason, source)
    started_at = Time.current
    result = tool.perform(tool_context, reason: reason, post_reason_as_note: true)
    record_fallback_handoff_tool_complete(tool, result, correlation_id, started_at)
    result
  rescue StandardError => e
    Rails.logger.warn("[AgentRunnerService] Fallback handoff invocation failed: #{e.message}")
  end

  def record_fallback_handoff_tool_start(tool, reason, source)
    return nil unless @trace_recorder.respond_to?(:enabled?) && @trace_recorder.enabled?

    correlation_id = @trace_recorder.new_correlation_id
    @trace_recorder.record(:tool_start, {
      tool: tool.name,
      args: { reason: reason.to_s.truncate(300) },
      correlation_id: correlation_id,
      trigger: 'fallback_escalation',
      source: source
    }.compact)
    correlation_id
  rescue StandardError => e
    Rails.logger.warn("[Captain::Trace] fallback handoff tool_start failed: #{e.message}")
    nil
  end

  def record_fallback_handoff_tool_complete(tool, result, correlation_id, started_at)
    return unless @trace_recorder.respond_to?(:enabled?) && @trace_recorder.enabled?

    duration_ms = ((Time.current - started_at) * 1000).round
    @trace_recorder.record(:tool_complete, {
      tool: tool.name,
      result: result.to_s.truncate(500),
      correlation_id: correlation_id,
      duration_ms: duration_ms,
      trigger: 'fallback_escalation'
    }.compact)
  rescue StandardError => e
    Rails.logger.warn("[Captain::Trace] fallback handoff tool_complete failed: #{e.message}")
  end

  def build_fallback_tool_context
    state = build_state
    run_context = Agents::RunContext.new({ state: state })
    Agents::ToolContext.new(run_context: run_context)
  end

  def error_response(error_message)
    {
      'response' => 'conversation_handoff',
      'reasoning' => "Error occurred: #{error_message}"
    }
  end

  # Treat upstream RubyLLM configuration errors the same as our pre-flight check —
  # they're infra/config failures, not business escalations.
  def infra_error?(error)
    error.is_a?(RubyLLM::ConfigurationError) ||
      error.is_a?(Llm::Config::ProviderNotConfiguredError) ||
      error.is_a?(Llm::Config::ProviderRequiredError) ||
      error.is_a?(Llm::Config::ModelNotAvailableForProviderError)
  end

  # Resolves the runtime provider/model pair used by this run. Provider falls
  # back to the chatwoot primary provider; model falls back to the account's
  # captain_assistant_model when valid for the chosen provider, otherwise to
  # the provider's default from llm.yml. The result is memoised so logging,
  # apply_to_globals! and agent construction all see the same pair.
  def resolve_runtime_llm_selection!
    @resolved_provider = (@runtime_provider.presence || Llm::Config.primary_chatwoot_provider).to_s
    raise Llm::Config::ProviderRequiredError if @resolved_provider.blank?

    runtime_model_candidate = @runtime_model.presence || account_assistant_model
    @resolved_model = Llm::Config.resolve_runtime_model(provider: @resolved_provider, model: runtime_model_candidate)
  end

  def account_assistant_model
    @assistant.account.captain_assistant_model
  rescue StandardError
    nil
  end

  def log_infra_error(error)
    provider = resolved_or_primary_provider_for_logging
    Rails.logger.error(
      '[Captain V2][LLM Config Error] ' \
      "provider=#{provider.inspect} " \
      "model=#{@resolved_model.inspect} " \
      "error_class=#{error.class.name} " \
      "message=#{error.message}"
    )
    record_trace_decision(
      :escalation_decision,
      domain: 'handoff', name: 'infra_provider_misconfigured',
      selected: true,
      reasoning_summary: "Captain LLM provider/model misconfigured: #{error.message}".truncate(500),
      inputs: { error_class: error.class.name, provider: provider.to_s, model: @resolved_model.to_s }
    )
  end

  def infra_error_response(error)
    provider = resolved_or_primary_provider_for_logging.to_s
    {
      'response' => 'conversation_handoff',
      'reasoning' => "Infra error: provider '#{provider}' misconfigured (#{error.class.name}: #{error.message})",
      'error_kind' => 'infra'
    }
  end

  def resolved_or_primary_provider_for_logging
    return @resolved_provider if @resolved_provider.present?

    Llm::Config.primary_chatwoot_provider
  rescue StandardError
    'unknown'
  end

  def build_state
    state = {
      account_id: @assistant.account_id,
      assistant_id: @assistant.id,
      assistant_config: @assistant.config,
      orchestration: runtime_state_service&.state || {},
      detected_language: runtime_state_service&.state&.dig('detected_language') || fallback_language
    }
    state[:source] = @source if @source.present?

    build_conversation_state(state) if @conversation
    state
  end

  def fallback_language
    @assistant.account.locale&.split('_')&.first || 'en'
  end

  def build_conversation_state(state)
    state[:conversation] = slice_attrs(@conversation, CONVERSATION_STATE_ATTRIBUTES)
    state[:channel_type] = @conversation.inbox&.channel_type
    state[:contact] = slice_attrs(@conversation.contact, CONTACT_STATE_ATTRIBUTES) if @conversation.contact
    state[:contact_inbox] = slice_attrs(@conversation.contact_inbox, CONTACT_INBOX_STATE_ATTRIBUTES) if @conversation.contact_inbox
  end

  def slice_attrs(record, keys)
    record.attributes.symbolize_keys.slice(*keys)
  end

  def build_and_wire_agents
    assistant_agent = @assistant.agent(runtime_model: @resolved_model)
    scenario_agents = @assistant.scenarios.enabled.map { |scenario| scenario.agent(runtime_model: @resolved_model) }

    assistant_agent.register_handoffs(*scenario_agents) if scenario_agents.any?
    scenario_agents.each { |scenario_agent| scenario_agent.register_handoffs(assistant_agent) }

    [assistant_agent] + scenario_agents
  end

  def install_instrumentation(runner)
    return unless ChatwootApp.otel_enabled?

    Agents::Instrumentation.install(
      runner,
      tracer: OpentelemetryConfig.tracer,
      trace_name: 'llm.captain_v2',
      span_attributes: {
        ATTR_LANGFUSE_TAGS => ['captain_v2'].to_json
      },
      attribute_provider: ->(context_wrapper) { dynamic_trace_attributes(context_wrapper) }
    )
    register_trace_input_callback(runner)
  end

  def dynamic_trace_attributes(context_wrapper)
    state = context_wrapper&.context&.dig(:state) || {}
    conversation = state[:conversation] || {}
    trace_input = context_wrapper&.context&.dig(:captain_v2_trace_input)

    {
      ATTR_LANGFUSE_USER_ID => state[:account_id],
      format(ATTR_LANGFUSE_METADATA, 'assistant_id') => state[:assistant_id],
      format(ATTR_LANGFUSE_METADATA, 'conversation_id') => conversation[:id],
      format(ATTR_LANGFUSE_METADATA, 'conversation_display_id') => conversation[:display_id],
      format(ATTR_LANGFUSE_METADATA, 'channel_type') => state[:channel_type],
      format(ATTR_LANGFUSE_METADATA, 'source') => state[:source],
      ATTR_LANGFUSE_TRACE_INPUT => trace_input,
      ATTR_LANGFUSE_OBSERVATION_INPUT => trace_input
    }.compact.transform_values(&:to_s)
  end

  def add_usage_metadata_callback(runner)
    handoff_tool_name = Captain::Tools::HandoffTool.new(@assistant).name
    faq_tool_name = Captain::Tools::FaqLookupTool.new(@assistant).name

    runner.on_tool_complete do |tool_name, tool_result, context_wrapper|
      preview = tool_result.is_a?(Hash) ? tool_result.inspect : tool_result.to_s
      Rails.logger.info(
        '[Captain DEBUG TMP] on_tool_complete ' \
        "tool_name=#{tool_name.inspect} result_preview=#{preview.truncate(500).inspect}"
      )
      record_tool_call(tool_name, context_wrapper)
      track_handoff_usage(tool_name, handoff_tool_name, context_wrapper)
      track_faq_usage(tool_name, faq_tool_name, tool_result, context_wrapper)
      persist_tool_runtime_state(tool_name, tool_result, context_wrapper)
    end

    runner.on_agent_handoff do |from_agent, to_agent, _reason, context_wrapper|
      append_private_note("Captain internal handoff: #{from_agent} -> #{to_agent}")
      persist_runtime_context!(context_wrapper, current_agent: to_agent)
    end

    runner.on_run_complete do |_agent_name, result, context_wrapper|
      write_credits_used_metadata(context_wrapper, result)
      log_routing_decision(context_wrapper, result)
      persist_runtime_context!(context_wrapper, current_agent: result.context&.dig(:current_agent),
                                                routing_decision: compute_routing_decision(context_wrapper, result))
    end
    runner
  end

  TOOL_HISTORY_MAX = 20

  def record_tool_call(tool_name, context_wrapper)
    return unless context_wrapper&.context

    state = context_wrapper.context[:state] ||= {}
    orch = state[:orchestration] ||= {}
    history = Array(orch[:tool_history])
    history << tool_name.to_s
    orch[:tool_history] = history.last(TOOL_HISTORY_MAX)
  end

  def track_handoff_usage(tool_name, handoff_tool_name, context_wrapper)
    return unless context_wrapper&.context
    return unless tool_name.to_s == handoff_tool_name

    context_wrapper.context[:captain_v2_handoff_tool_called] = true
  end

  def write_credits_used_metadata(context_wrapper, result = nil)
    root_span = context_wrapper&.context&.dig(:__otel_tracing, :root_span)
    return unless root_span

    credit_used = !context_wrapper.context[:captain_v2_handoff_tool_called]
    root_span.set_attribute(format(ATTR_LANGFUSE_METADATA, 'credit_used'), credit_used.to_s)

    retry_count = context_wrapper.context[:autonomy_retry_count]
    root_span.set_attribute(format(ATTR_LANGFUSE_METADATA, 'autonomy_retry_count'), retry_count.to_s) if retry_count

    scenario_detected = context_wrapper.context[:scenario_router_attempted]
    root_span.set_attribute(format(ATTR_LANGFUSE_METADATA, 'scenario_detected'), scenario_detected.to_s) if scenario_detected

    conversation_length = context_wrapper.context[:conversation_length]
    root_span.set_attribute(format(ATTR_LANGFUSE_METADATA, 'conversation_length_at_routing'), conversation_length.to_s) if conversation_length

    routing_decision = compute_routing_decision(context_wrapper, result)
    root_span.set_attribute(format(ATTR_LANGFUSE_METADATA, 'orchestrator_routing_decision'), routing_decision) if routing_decision
  end

  def compute_routing_decision(context_wrapper, result)
    return nil unless context_wrapper&.context

    return 'scenario_handoff' if scenario_agent_responded?(result)
    return 'human' if human_handoff_response?(result)
    return 'faq' if context_wrapper.context[:captain_v2_faq_lookup_called]

    'direct'
  end

  def scenario_agent_responded?(result)
    agent_name = result.respond_to?(:context) ? result.context&.dig(:current_agent) : nil
    return false if agent_name.blank?

    assistant_agent_name = @assistant.name.parameterize(separator: '_')
    agent_name.to_s != assistant_agent_name
  end

  def human_handoff_response?(result)
    output = result.respond_to?(:output) ? result.output : nil
    response_text = output.is_a?(Hash) ? (output['response'] || output[:response]).to_s : output.to_s
    response_text == 'conversation_handoff'
  end

  def log_routing_decision(context_wrapper, result)
    return unless context_wrapper&.context

    routing_decision = compute_routing_decision(context_wrapper, result)
    conversation_length = context_wrapper.context[:conversation_length]
    Rails.logger.info(
      '[Captain V2] orchestrator_routing_decision=' << routing_decision.to_s <<
      ' conversation_length_at_routing=' << conversation_length.to_s
    )
  end

  def persist_tool_runtime_state(tool_name, _tool_result, context_wrapper)
    return unless context_wrapper&.context

    append_private_note('Captain escalated the conversation to a human agent.') if tool_name.to_s == Captain::Tools::HandoffTool.new(@assistant).name

    persist_runtime_context!(context_wrapper)
  end

  def runner
    @runner ||= begin
      configured_runner = Agents::Runner.with_agents(*build_and_wire_agents)
      configured_runner = add_usage_metadata_callback(configured_runner)
      configured_runner = register_llm_prompt_logging(configured_runner)
      configured_runner = add_callbacks_to_runner(configured_runner) if @callbacks.any?
      install_instrumentation(configured_runner)
      configured_runner
    end
  end

  def run_payload(message_history)
    message_to_process = extract_last_user_message(message_history)
    context = build_context(message_history_without_last_user_message(message_history))
    context[:conversation_length] = message_history.size
    if message_history.size > 7
      last_text = message_to_process.respond_to?(:to_s) ? message_to_process.to_s : message_to_process
      router = Captain::ScenarioRouterService.new(last_text, @assistant)
      if router.scenarios_available?
        context[:routing_hint] = router.routing_hint
        context[:routing_plan] = router.routing_plan
      end
    end
    attach_prefetched_knowledge!(context, message_to_process)
    enrich_context_with_trace_payload!(context, message_history, message_to_process)
    enrich_context_with_runtime_state!(context)
    [message_to_process, context]
  end

  # Pre-fetch FAQ search before the LLM call. When knowledge_mode is set on the
  # assistant we run UnifiedSearchService + PolicyDecision (no LLM, just pgvector
  # + threshold) and inject the result into the system prompt, so the model
  # answers from concrete sources instead of promising to "check" via a tool
  # call that some providers (e.g. DeepSeek under tool_choice=auto) skip.
  def attach_prefetched_knowledge!(context, user_message)
    return unless prefetch_eligible?(context)

    query = user_message.to_s.strip
    return if query.blank?

    decision = run_knowledge_prefetch(query)
    context[:prefetched_knowledge] = decision
    record_knowledge_hit_trace(decision, query)
  rescue StandardError => e
    Rails.logger.error("[Captain V2] knowledge prefetch failed: #{e.class}: #{e.message}")
    return unless trace_recorder_active?

    @trace_recorder.record(:error, { stage: 'knowledge_prefetch', message: e.message })
  end

  def prefetch_eligible?(context)
    return false if @assistant.knowledge_mode.blank?
    return false if context[:routing_hint].to_s.start_with?('scenario')

    true
  end

  def run_knowledge_prefetch(query)
    results = Captain::Knowledge::UnifiedSearchService.new(assistant: @assistant).search(query)
    decision = Captain::Knowledge::PolicyDecision.new(
      assistant: @assistant, search_results: results
    ).decide
    decision[:query] = query
    decision
  end

  def record_knowledge_hit_trace(decision, query)
    return unless trace_recorder_active?

    @trace_recorder.record(:knowledge_hit, {
                             stage: 'prefetch',
                             policy: decision[:policy],
                             confidence: decision[:confidence],
                             sources_count: Array(decision[:sources]).size,
                             query_preview: query.truncate(120)
                           })
  end

  def trace_recorder_active?
    @trace_recorder.respond_to?(:record) && @trace_recorder.enabled?
  end

  def runtime_state_service
    return @runtime_state_service if defined?(@runtime_state_service)

    @runtime_state_service = @conversation ? Captain::RuntimeStateService.new(@conversation) : nil
  end

  def with_conversation_lock
    return yield unless @conversation

    lock_manager = Redis::LockManager.new
    lock_key = "captain:agent_runner:conversation:#{@conversation.id}"
    lock_acquired = lock_manager.lock(lock_key, 2.minutes)
    return busy_response unless lock_acquired

    runtime_state_service&.update_state(last_run_started_at: Time.current.iso8601)
    yield
  ensure
    lock_manager&.unlock(lock_key) if @conversation && lock_acquired
  end

  def busy_response
    {
      'response' => nil,
      'reasoning' => 'Skipped concurrent orchestration run'
    }
  end

  def persist_runtime_context!(context_wrapper, current_agent: nil, routing_decision: nil)
    return unless runtime_state_service && context_wrapper&.context

    orchestration = context_wrapper.context[:state]&.dig(:orchestration) || {}
    runtime_state_service.update_state(
      current_agent: current_agent || context_wrapper.context[:current_agent],
      handoff_trace: context_wrapper.context[:handoff_trace],
      last_handoff: context_wrapper.context[:last_handoff],
      last_routing_decision: routing_decision,
      last_faq_lookup: orchestration[:last_faq_lookup],
      last_knowledge_prefetch_policy: context_wrapper.context.dig(:prefetched_knowledge, :policy),
      last_http_tool_result: orchestration[:last_http_tool_result],
      pending_human_interaction: orchestration[:pending_human_interaction] || runtime_state_service.state['pending_human_interaction'],
      pending_customer_confirm: resolve_pending_customer_confirm(orchestration),
      last_run_completed_at: Time.current.iso8601
    )
  end

  # rubocop:disable Metrics/PerceivedComplexity
  def resolve_pending_customer_confirm(orchestration)
    new_pending = orchestration[:pending_customer_confirm] || orchestration['pending_customer_confirm']
    return new_pending if new_pending.present?

    stored = runtime_state_service&.state&.dig('pending_customer_confirm')
    return nil if stored.blank?

    planned_tool = stored.is_a?(Hash) ? (stored['on_confirm_tool'] || stored[:on_confirm_tool]).to_s.downcase : ''
    return stored if planned_tool.blank?

    planned_invoked?(orchestration, planned_tool) ? nil : stored
  end
  # rubocop:enable Metrics/PerceivedComplexity

  def planned_invoked?(orchestration, planned_tool)
    history = Array(orchestration[:tool_history] || orchestration['tool_history'])
    history.any? { |name| name.to_s.delete_prefix('captain--tools--').downcase == planned_tool }
  end

  def append_private_note(content)
    return unless @conversation
    return if content.blank?

    @conversation.messages.create!(
      message_type: :outgoing,
      private: true,
      sender: @assistant,
      account: @conversation.account,
      inbox: @conversation.inbox,
      content: content
    )
  end
end
# rubocop:enable Metrics/ClassLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
