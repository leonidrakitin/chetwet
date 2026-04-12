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

  def initialize(assistant:, conversation: nil, callbacks: {}, source: nil)
    @assistant = assistant
    @conversation = conversation
    @callbacks = callbacks
    @source = source
  end

  def generate_response(message_history: [])
    message_to_process, context = run_payload(message_history)
    Rails.logger.info(
      '[Captain DEBUG TMP] AgentRunnerService#generate_response start ' \
      "assistant_id=#{@assistant.id} conversation_id=#{@conversation&.id} source=#{@source.inspect}"
    )

    with_conversation_lock do
      result = run_with_autonomy_policy(message_to_process, context)
      process_agent_result(result)
    end
  rescue StandardError => e
    # In rake/local runs, conversation may not be present, so account is optional here.
    ChatwootExceptionTracker.new(e, account: @conversation&.account).capture_exception
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
    normalize_escalation_response!(response)
    text = response['response'].to_s
    Rails.logger.info(
      '[Captain DEBUG TMP] process_agent_result ' \
      "current_agent=#{result.context&.dig(:current_agent).inspect} " \
      "response_preview=#{text.truncate(400).inspect} " \
      "faq_lookup_called=#{result.context&.dig(:captain_v2_faq_lookup_called)}"
    )
    response
  end

  def normalize_escalation_response!(response)
    reasoning = response['reasoning'].to_s
    return if response['response'].to_s == 'conversation_handoff'
    return unless escalation_intent_detected?(reasoning)

    Rails.logger.info(
      '[Captain DEBUG TMP] normalize_escalation_response ' \
      'reasoning_detected=true ' \
      "response_preview=#{response['response'].to_s.truncate(200).inspect}"
    )
    invoke_handoff_tool_fallback(response)
    response['response'] = 'conversation_handoff'
  end

  def invoke_handoff_tool_fallback(response)
    return unless @conversation

    reason = response['reasoning'].to_s.truncate(500).presence ||
             'Auto-escalation: LLM signaled escalation without calling tool'
    tool = Captain::Tools::HandoffTool.new(@assistant)
    tool_context = build_fallback_tool_context
    tool.perform(tool_context, reason: reason, post_reason_as_note: true)
  rescue StandardError => e
    Rails.logger.warn("[AgentRunnerService] Fallback handoff invocation failed: #{e.message}")
  end

  def build_fallback_tool_context
    state = build_state
    run_context = Agents::RunContext.new({ state: state })
    Agents::ToolContext.new(run_context: run_context)
  end

  def escalation_intent_detected?(reasoning)
    return false if reasoning.blank?

    # Matches Russian "эскалир", "перевод на оператора", "связать с человеком"
    # and English "escalat", "transfer to human", "hand over to operator"
    reasoning.match?(/\bescalat/i) ||
      reasoning.match?(/\bhandoff\b/i) ||
      reasoning.match?(/эскалир/i) ||
      reasoning.match?(/перевод\w* на оператора/i) ||
      reasoning.match?(/связать с человеком/i) ||
      reasoning.match?(/transfer to human/i)
  end

  def error_response(error_message)
    {
      'response' => 'conversation_handoff',
      'reasoning' => "Error occurred: #{error_message}"
    }
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
    assistant_agent = @assistant.agent
    scenario_agents = @assistant.scenarios.enabled.map(&:agent)

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
    enrich_context_with_trace_payload!(context, message_history, message_to_process)
    enrich_context_with_runtime_state!(context)
    [message_to_process, context]
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
      last_http_tool_result: orchestration[:last_http_tool_result],
      pending_human_interaction: orchestration[:pending_human_interaction] || runtime_state_service.state['pending_human_interaction'],
      last_run_completed_at: Time.current.iso8601
    )
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
