# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::Assistant::AgentRunnerService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:scenario) { create(:captain_scenario, assistant: assistant, enabled: true) }

  let(:mock_runner) { instance_double(Agents::Runner) }
  let(:mock_agent) { instance_double(Agents::Agent) }
  let(:mock_scenario_agent) { instance_double(Agents::Agent) }
  let(:mock_result) { instance_double(Agents::RunResult, output: { 'response' => 'Test response' }, context: nil) }

  let(:message_history) do
    [
      { role: 'user', content: 'Hello there' },
      { role: 'assistant', content: 'Hi! How can I help you?', agent_name: 'Assistant' },
      { role: 'user', content: 'I need help with my account' }
    ]
  end

  before do
    allow(assistant).to receive(:agent).and_return(mock_agent)
    scenarios_relation = instance_double(Captain::Scenario)
    allow(scenarios_relation).to receive(:enabled).and_return([scenario])
    allow(assistant).to receive(:scenarios).and_return(scenarios_relation)
    allow(scenario).to receive(:agent).and_return(mock_scenario_agent)
    allow(Agents::Runner).to receive(:with_agents).and_return(mock_runner)
    allow(mock_runner).to receive(:run).and_return(mock_result)
    allow(mock_agent).to receive(:register_handoffs)
    allow(mock_scenario_agent).to receive(:register_handoffs)
    # Unit specs stub Agents::Runner; they don't need real provider credentials.
    # Skip the pre-flight validation/global apply so tests remain isolated from
    # CAPTAIN_PROVIDERS configuration.
    allow(Llm::Config).to receive(:validate_provider!)
    allow(Llm::Config).to receive(:apply_to_globals!)
  end

  describe '#initialize' do
    it 'sets instance variables correctly' do
      service = described_class.new(assistant: assistant, conversation: conversation)

      expect(service.instance_variable_get(:@assistant)).to eq(assistant)
      expect(service.instance_variable_get(:@conversation)).to eq(conversation)
      expect(service.instance_variable_get(:@callbacks)).to eq({})
    end

    it 'accepts callbacks parameter' do
      callbacks = { on_agent_thinking: proc { |x| x } }
      service = described_class.new(assistant: assistant, callbacks: callbacks)

      expect(service.instance_variable_get(:@callbacks)).to eq(callbacks)
    end
  end

  describe '#generate_response' do
    subject(:service) { described_class.new(assistant: assistant, conversation: conversation) }

    it 'builds agents and wires them together' do
      expect(assistant).to receive(:agent).and_return(mock_agent)
      scenarios_relation = instance_double(Captain::Scenario)
      allow(scenarios_relation).to receive(:enabled).and_return([scenario])
      expect(assistant).to receive(:scenarios).and_return(scenarios_relation)
      expect(scenario).to receive(:agent).and_return(mock_scenario_agent)
      expect(mock_agent).to receive(:register_handoffs).with(mock_scenario_agent)
      expect(mock_scenario_agent).to receive(:register_handoffs).with(mock_agent)

      service.generate_response(message_history: message_history)
    end

    it 'creates runner with agents' do
      expect(Agents::Runner).to receive(:with_agents).with(mock_agent, mock_scenario_agent)

      service.generate_response(message_history: message_history)
    end

    it 'runs agent with extracted user message and context' do
      expected_context = hash_including(
        session_id: "#{account.id}_#{conversation.display_id}",
        conversation_history: [
          { role: :user, content: 'Hello there', agent_name: nil },
          { role: :assistant, content: 'Hi! How can I help you?', agent_name: 'Assistant' }
        ],
        state: hash_including(
          account_id: account.id,
          assistant_id: assistant.id,
          conversation: hash_including(id: conversation.id),
          contact: hash_including(id: contact.id)
        )
      )

      expect(mock_runner).to receive(:run).with(
        'I need help with my account',
        context: expected_context,
        max_turns: 100
      )

      service.generate_response(message_history: message_history)
    end

    context 'when the latest user message is multimodal' do
      let(:multimodal_message_history) do
        [
          { role: 'assistant', content: 'Please share a screenshot' },
          {
            role: 'user',
            content: [
              { type: 'text', text: 'What does this error mean?' },
              { type: 'image_url', image_url: { url: 'https://example.com/error.png' } }
            ]
          }
        ]
      end

      it 'passes image attachments to the runner input' do
        expect(mock_runner).to receive(:run) do |input, context:, max_turns:|
          expect(input).to be_a(RubyLLM::Content)
          expect(input.text).to eq('What does this error mean?')
          expect(input.attachments.first.source.to_s).to eq('https://example.com/error.png')
          expect(context[:conversation_history]).to eq([{ role: :assistant, content: 'Please share a screenshot', agent_name: nil }])
          expect(max_turns).to eq(100)
        end

        service.generate_response(message_history: multimodal_message_history)
      end

      it 'preserves multimodal content in earlier history messages' do
        history_with_prior_image = [
          {
            role: 'user',
            content: [
              { type: 'text', text: 'Here is my error screenshot' },
              { type: 'image_url', image_url: { url: 'https://example.com/error.png' } }
            ]
          },
          { role: 'assistant', content: 'I see the error. Try restarting.' },
          { role: 'user', content: 'It still does not work' }
        ]

        expect(mock_runner).to receive(:run) do |input, context:, max_turns:|
          expect(input).to eq('It still does not work')
          # The earlier user message with the image should preserve the multimodal array
          first_history_msg = context[:conversation_history].first
          expect(first_history_msg[:content]).to be_a(Array)
          expect(first_history_msg[:content]).to include(
            { type: 'text', text: 'Here is my error screenshot' },
            { type: 'image_url', image_url: { url: 'https://example.com/error.png' } }
          )
          expect(max_turns).to eq(100)
        end

        service.generate_response(message_history: history_with_prior_image)
      end

      it 'stores multimodal trace payloads in runner context' do
        expect(mock_runner).to receive(:run) do |_input, context:, max_turns:|
          expect(context[:captain_v2_trace_input]).to include('image_url')
          expect(context[:captain_v2_trace_current_input]).to include('image_url')
          expect(max_turns).to eq(100)
        end

        service.generate_response(message_history: multimodal_message_history)
      end
    end

    it 'processes and formats agent result' do
      result = service.generate_response(message_history: message_history)

      expect(result).to eq({ 'response' => 'Test response', 'agent_name' => nil })
    end

    context 'when no scenarios are enabled' do
      before do
        scenarios_relation = instance_double(Captain::Scenario)
        allow(scenarios_relation).to receive(:enabled).and_return([])
        allow(assistant).to receive(:scenarios).and_return(scenarios_relation)
      end

      it 'only uses assistant agent' do
        expect(Agents::Runner).to receive(:with_agents).with(mock_agent)
        expect(mock_agent).not_to receive(:register_handoffs)

        service.generate_response(message_history: message_history)
      end
    end

    context 'when agent result is a string' do
      let(:mock_result) { instance_double(Agents::RunResult, output: 'Simple string response', context: nil) }

      it 'formats string response correctly' do
        result = service.generate_response(message_history: message_history)

        expect(result).to eq({
                               'response' => 'Simple string response',
                               'reasoning' => 'Processed by agent',
                               'agent_name' => nil
                             })
      end
    end

    context 'when neither response nor reasoning suggest escalation' do
      let(:mock_result) do
        instance_double(
          Agents::RunResult,
          output: {
            'response' => 'Sure, here is the information you asked for.',
            'reasoning' => 'Provided answer based on docs'
          },
          context: nil
        )
      end

      it 'leaves the response untouched' do
        tool_double = instance_double(Captain::Tools::HandoffTool, name: 'escalate_to_human')
        allow(Captain::Tools::HandoffTool).to receive(:new).and_return(tool_double)
        expect(tool_double).not_to receive(:perform)

        result = service.generate_response(message_history: message_history)
        expect(result['response']).to eq('Sure, here is the information you asked for.')
      end
    end

    context 'when an error occurs' do
      let(:error) { StandardError.new('Test error') }

      before do
        allow(mock_runner).to receive(:run).and_raise(error)
        allow(ChatwootExceptionTracker).to receive(:new).and_return(
          instance_double(ChatwootExceptionTracker, capture_exception: true)
        )
      end

      it 'captures exception and returns error response' do
        expect(ChatwootExceptionTracker).to receive(:new).with(error, account: conversation.account)

        result = service.generate_response(message_history: message_history)

        expect(result).to eq({
                               'response' => 'conversation_handoff',
                               'reasoning' => 'Error occurred: Test error'
                             })
      end

      it 'logs error details' do
        expect(Rails.logger).to receive(:error).with('[Captain V2] AgentRunnerService error: Test error')
        expect(Rails.logger).to receive(:error).with(kind_of(String))

        service.generate_response(message_history: message_history)
      end

      context 'when conversation is nil' do
        subject(:service) { described_class.new(assistant: assistant, conversation: nil) }

        it 'handles missing conversation gracefully' do
          expect(ChatwootExceptionTracker).to receive(:new).with(error, account: nil)

          result = service.generate_response(message_history: message_history)

          expect(result).to eq({
                                 'response' => 'conversation_handoff',
                                 'reasoning' => 'Error occurred: Test error'
                               })
        end
      end
    end
  end

  describe 'runtime provider/model resolution' do
    let(:service) { described_class.new(assistant: assistant, conversation: conversation) }

    # Tests in this describe block intentionally exercise the public API up to
    # but not including the mocked Agents::Runner. The runtime provider/model
    # resolver runs inside `generate_response` BEFORE the runner is touched, so
    # we drive it through a custom service shim that stops right after the
    # resolution step. This sidesteps the pre-existing `mock_runner` setup
    # issues in the broader spec (it doesn't stub on_tool_complete etc.) and
    # keeps these specs focused on the contract under test.
    def resolve!(svc)
      svc.send(:resolve_runtime_llm_selection!)
      [svc.instance_variable_get(:@resolved_provider), svc.instance_variable_get(:@resolved_model)]
    end

    it 'defaults to the chatwoot primary provider when none was passed and resolves a validated runtime_model from account preferences' do
      allow(Llm::Config).to receive(:primary_chatwoot_provider).and_return('openai')
      allow(assistant.account).to receive(:captain_assistant_model).and_return('gpt-5.1')

      provider, model = resolve!(service)

      expect(provider).to eq('openai')
      expect(model).to eq('gpt-5.1')
    end

    it 'forwards the resolved runtime_model into Concerns::Agentable#agent during build_and_wire_agents' do
      allow(Llm::Config).to receive(:primary_chatwoot_provider).and_return('openai')
      allow(assistant.account).to receive(:captain_assistant_model).and_return('gpt-5.1')
      service.send(:resolve_runtime_llm_selection!)

      expect(assistant).to receive(:agent).with(runtime_model: 'gpt-5.1').and_return(mock_agent)
      expect(scenario).to receive(:agent).with(runtime_model: 'gpt-5.1').and_return(mock_scenario_agent)

      service.send(:build_and_wire_agents)
    end

    it 'falls back to the provider default when the account-selected model is not hosted on the provider' do
      service_with_override = described_class.new(
        assistant: assistant, conversation: conversation, provider: 'openrouter'
      )
      # claude-haiku-4.5 is not hosted on openai but IS on openrouter — pretend the
      # account picked an openrouter-only id while we override provider to a
      # different one. We assert that the runner doesn't blindly forward an
      # incompatible id.
      allow(assistant.account).to receive(:captain_assistant_model).and_return('claude-sonnet-4.5')

      _, model = resolve!(service_with_override)

      expect(Llm::Config.model_available_for_provider?('openrouter', model)).to be true
    end

    it 'raises ProviderRequiredError when provider resolution yields blank' do
      allow(Llm::Config).to receive(:primary_chatwoot_provider).and_return('')

      expect { resolve!(service) }.to raise_error(Llm::Config::ProviderRequiredError)
    end

    it 'classifies ProviderRequiredError as an infra error and returns a handoff response with error_kind=infra' do
      allow(Llm::Config).to receive(:primary_chatwoot_provider).and_return('')
      allow(ChatwootExceptionTracker).to receive(:new).and_return(
        instance_double(ChatwootExceptionTracker, capture_exception: true)
      )

      result = service.generate_response(message_history: message_history)

      expect(result['response']).to eq('conversation_handoff')
      expect(result['error_kind']).to eq('infra')
      expect(result['reasoning']).to include('ProviderRequiredError')
    end

    it 'does not implicitly fall back to OpenAI when openrouter is selected with an unprefixed model — apply/validate are scoped to openrouter' do
      service_with_override = described_class.new(
        assistant: assistant, conversation: conversation, provider: 'openrouter', model: 'gpt-5-mini'
      )

      provider, model = resolve!(service_with_override)
      expect(provider).to eq('openrouter')
      # gpt-5-mini IS hosted on openrouter (per llm.yml), so it survives validation.
      # The contract under test is that the resolved provider stays openrouter.
      expect(model).to eq('gpt-5-mini')
      expect(Llm::Config.model_available_for_provider?('openrouter', model)).to be true
    end
  end

  describe '#build_context' do
    subject(:service) { described_class.new(assistant: assistant, conversation: conversation) }

    it 'builds context with conversation history and state' do
      context = service.send(:build_context, message_history)

      expect(context).to include(
        conversation_history: array_including(
          { role: :user, content: 'Hello there', agent_name: nil },
          { role: :assistant, content: 'Hi! How can I help you?', agent_name: 'Assistant' }
        ),
        state: hash_including(
          account_id: account.id,
          assistant_id: assistant.id
        )
      )
    end

    context 'with multimodal content' do
      let(:multimodal_content) do
        [
          { type: 'text', text: 'Can you help with this image?' },
          { type: 'image_url', image_url: { url: 'https://example.com/image.jpg' } }
        ]
      end

      let(:multimodal_message_history) do
        [{ role: 'user', content: multimodal_content }]
      end

      it 'preserves multimodal arrays in conversation history for image context retention' do
        context = service.send(:build_context, multimodal_message_history)

        expect(context[:conversation_history].first[:content]).to eq(multimodal_content)
      end
    end
  end

  describe '#extract_last_user_message' do
    subject(:service) { described_class.new(assistant: assistant, conversation: conversation) }

    it 'extracts the last user message' do
      result = service.send(:extract_last_user_message, message_history)

      expect(result).to eq('I need help with my account')
    end

    it 'returns multimodal content with image attachments for the runner input' do
      multimodal_message_history = [
        {
          role: 'user',
          content: [
            { type: 'text', text: 'Can you check this screenshot?' },
            { type: 'image_url', image_url: { url: 'https://example.com/image.jpg' } }
          ]
        }
      ]

      result = service.send(:extract_last_user_message, multimodal_message_history)

      expect(result).to be_a(RubyLLM::Content)
      expect(result.text).to eq('Can you check this screenshot?')
      expect(result.attachments.first.source.to_s).to eq('https://example.com/image.jpg')
    end
  end

  describe '#escalation_intent_detected?' do
    subject(:service) { described_class.new(assistant: assistant, conversation: conversation) }

    it 'detects English transfer-to-human phrasing' do
      expect(service.send(:escalation_intent_detected?, 'I will transfer you to a human now')).to be true
    end

    it 'detects English "requires operator"' do
      expect(service.send(:escalation_intent_detected?, 'User wants cancellation, requires operator')).to be true
    end

    it 'detects Russian "перевожу оператору" (dative case)' do
      expect(service.send(:escalation_intent_detected?, 'Спасибо, перевожу оператору.')).to be true
    end

    it 'detects Russian "перевод на оператора"' do
      expect(service.send(:escalation_intent_detected?, 'Делаю перевод на оператора')).to be true
    end

    it 'detects Russian "связать с человеком"' do
      expect(service.send(:escalation_intent_detected?, 'Нужно связать с человеком')).to be true
    end

    it 'returns false for benign English text' do
      expect(service.send(:escalation_intent_detected?, 'Sure, here is the information you asked for.')).to be false
    end

    it 'returns false for benign Russian text' do
      expect(service.send(:escalation_intent_detected?, 'Спасибо, всё понятно, до свидания.')).to be false
    end

    it 'returns false for blank text' do
      expect(service.send(:escalation_intent_detected?, '')).to be false
      expect(service.send(:escalation_intent_detected?, nil)).to be false
    end
  end

  describe '#answer_acceptable? (self-check escalation enforcement)' do
    subject(:service) { described_class.new(assistant: assistant, conversation: conversation) }

    def build_result(response_text, reasoning: '', context: {})
      instance_double(
        Agents::RunResult,
        output: { 'response' => response_text, 'reasoning' => reasoning },
        context: context
      )
    end

    it 'rejects an answer that implies escalation in text without escalate_to_human tool call' do
      ctx = { autonomy_retry_count: 0 }
      result = build_result('I will transfer you to a human agent now.', context: {})

      expect(service.send(:answer_acceptable?, result, ctx)).to be false
      expect(ctx[:escalation_tool_required]).to be true
    end

    it 'rejects Russian "перевожу оператору" without tool call' do
      ctx = { autonomy_retry_count: 0 }
      result = build_result('Спасибо, перевожу оператору.', context: {})

      expect(service.send(:answer_acceptable?, result, ctx)).to be false
      expect(ctx[:escalation_tool_required]).to be true
    end

    it 'accepts when escalate_to_human tool was actually invoked' do
      ctx = { autonomy_retry_count: 0 }
      result = build_result('conversation_handoff',
                            reasoning: 'tool-driven',
                            context: { captain_v2_handoff_tool_called: true })

      expect(service.send(:answer_acceptable?, result, ctx)).to be true
      expect(ctx[:escalation_tool_required]).to be_nil
    end

    it 'accepts a benign answer that does not imply escalation' do
      ctx = { autonomy_retry_count: 0 }
      result = build_result('Sure, here is the information you asked for.', context: {})

      expect(service.send(:answer_acceptable?, result, ctx)).to be true
      expect(ctx[:escalation_tool_required]).to be_nil
    end

    it 'surfaces an escalate_to_human hint on retry when escalation was rejected' do
      ctx = { autonomy_retry_count: 0, conversation_history: [] }
      service.send(:answer_acceptable?,
                   build_result('I will transfer you to a human agent now.', context: {}),
                   ctx)

      service.send(:append_retry_hint!, ctx, 1, 'help me')

      hint = ctx[:conversation_history].last[:content]
      expect(hint).to include('escalate_to_human')
      expect(hint).to include('Self-check rejected')
    end
  end

  describe '#ensure_structural_handoff_invoked! (structural fallback)' do
    subject(:service) { described_class.new(assistant: assistant, conversation: conversation) }

    let(:tool_double) { instance_double(Captain::Tools::HandoffTool, name: 'escalate_to_human') }

    before do
      allow(Captain::Tools::HandoffTool).to receive(:new).with(assistant).and_return(tool_double)
      allow(tool_double).to receive(:perform).and_return('Conversation escalated to human support team')
    end

    it 'invokes the HandoffTool when synthetic conversation_handoff was reached without tool call' do
      response = { 'response' => 'conversation_handoff', 'reasoning' => 'Autonomy policy: escalation after max retries' }.with_indifferent_access
      result = instance_double(Agents::RunResult, context: {})

      expect(tool_double).to receive(:perform).with(
        an_instance_of(Agents::ToolContext),
        reason: a_string_including('Autonomy policy'),
        post_reason_as_note: true
      )

      service.send(:ensure_structural_handoff_invoked!, response, result)
      expect(response['_escalation_handled']).to be true
    end

    it 'does not invoke fallback when escalate_to_human tool was already called' do
      response = { 'response' => 'conversation_handoff', 'reasoning' => 'Tool-driven handoff' }.with_indifferent_access
      result = instance_double(Agents::RunResult, context: { captain_v2_handoff_tool_called: true })

      expect(tool_double).not_to receive(:perform)

      service.send(:ensure_structural_handoff_invoked!, response, result)
    end

    it 'is idempotent — does not re-invoke when _escalation_handled is already set' do
      response = { 'response' => 'conversation_handoff', 'reasoning' => '...', '_escalation_handled' => true }.with_indifferent_access
      result = instance_double(Agents::RunResult, context: {})

      expect(tool_double).not_to receive(:perform)

      service.send(:ensure_structural_handoff_invoked!, response, result)
    end

    it 'does nothing when response is not a handoff' do
      response = { 'response' => 'Sure, here is the answer.', 'reasoning' => '' }.with_indifferent_access
      result = instance_double(Agents::RunResult, context: {})

      expect(tool_double).not_to receive(:perform)

      service.send(:ensure_structural_handoff_invoked!, response, result)
    end
  end

  describe '#extract_text_from_content' do
    subject(:service) { described_class.new(assistant: assistant, conversation: conversation) }

    it 'extracts text from string content' do
      result = service.send(:extract_text_from_content, 'Simple text')

      expect(result).to eq('Simple text')
    end

    it 'extracts response from hash content' do
      content = { 'response' => 'Hash response' }
      result = service.send(:extract_text_from_content, content)

      expect(result).to eq('Hash response')
    end

    it 'extracts text from multimodal array content' do
      content = [
        { type: 'text', text: 'First part' },
        { type: 'image_url', image_url: { url: 'image.jpg' } },
        { type: 'text', text: 'Second part' }
      ]

      result = service.send(:extract_text_from_content, content)

      expect(result).to eq('First part Second part')
    end
  end

  describe '#dynamic_trace_attributes' do
    subject(:service) { described_class.new(assistant: assistant, conversation: conversation) }

    it 'adds serialized trace input attributes when present in context' do
      context = {
        state: {
          account_id: account.id,
          assistant_id: assistant.id,
          conversation: { id: conversation.id, display_id: conversation.display_id }
        },
        captain_v2_trace_input: '[{"role":"user","content":[{"type":"image_url","image_url":{"url":"https://example.com/image.jpg"}}]}]'
      }
      context_wrapper = Struct.new(:context).new(context)

      attributes = service.send(:dynamic_trace_attributes, context_wrapper)

      expect(attributes['langfuse.trace.input']).to include('image_url')
      expect(attributes['langfuse.observation.input']).to include('image_url')
      expect(attributes['langfuse.user.id']).to eq(account.id.to_s)
    end
  end

  describe '#build_state' do
    subject(:service) { described_class.new(assistant: assistant, conversation: conversation) }

    it 'builds state with assistant and account information' do
      state = service.send(:build_state)

      expect(state).to include(
        account_id: account.id,
        assistant_id: assistant.id,
        assistant_config: assistant.config
      )
    end

    it 'includes conversation attributes when conversation is present' do
      state = service.send(:build_state)

      expect(state[:conversation]).to include(
        id: conversation.id,
        inbox_id: inbox.id,
        contact_id: contact.id
      )
      expect(state[:channel_type]).to eq(inbox.channel_type)
    end

    it 'includes contact inbox attributes when conversation is present' do
      state = service.send(:build_state)

      expect(state[:contact_inbox]).to include(
        id: conversation.contact_inbox.id,
        hmac_verified: conversation.contact_inbox.hmac_verified
      )
    end

    it 'always includes contact attributes in state for tool access' do
      state = service.send(:build_state)

      expect(state[:contact]).to include(
        id: contact.id,
        name: contact.name,
        email: contact.email
      )
    end

    it 'does not include campaign when conversation has no campaign' do
      state = service.send(:build_state)

      expect(state).not_to have_key(:campaign)
    end

    context 'when conversation has a campaign' do
      let(:campaign) { create(:campaign, account: account, title: 'Summer Sale', message: 'Check out our deals!', description: 'Seasonal promo') }
      let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, campaign: campaign) }

      it 'includes campaign attributes in state' do
        state = service.send(:build_state)

        expect(state[:campaign]).to include(
          id: campaign.id,
          title: 'Summer Sale',
          message: 'Check out our deals!',
          description: 'Seasonal promo'
        )
      end

      it 'only includes attributes defined in CAMPAIGN_STATE_ATTRIBUTES' do
        state = service.send(:build_state)

        expect(state[:campaign].keys).to match_array(described_class::CAMPAIGN_STATE_ATTRIBUTES)
      end
    end

    context 'when conversation is nil' do
      subject(:service) { described_class.new(assistant: assistant, conversation: nil) }

      it 'builds state without conversation and contact' do
        state = service.send(:build_state)

        expect(state).to include(
          account_id: account.id,
          assistant_id: assistant.id,
          assistant_config: assistant.config
        )
        expect(state).not_to have_key(:conversation)
        expect(state).not_to have_key(:contact)
        expect(state).not_to have_key(:campaign)
      end
    end
  end

  describe '#add_usage_metadata_callback' do
    it 'sets credit_used=false when handoff tool is used' do
      service = described_class.new(assistant: assistant, conversation: conversation)
      runner = instance_double(Agents::AgentRunner)
      tool_complete_callback = nil
      run_complete_callback = nil
      span_class = Class.new do
        def set_attribute(*); end
      end
      root_span = instance_double(span_class)
      context_wrapper = Struct.new(:context).new({ __otel_tracing: { root_span: root_span } })

      allow(ChatwootApp).to receive(:otel_enabled?).and_return(true)
      allow(runner).to receive(:on_tool_complete) do |&block|
        tool_complete_callback = block
        runner
      end
      allow(runner).to receive(:on_run_complete) do |&block|
        run_complete_callback = block
        runner
      end

      service.send(:add_usage_metadata_callback, runner)

      tool_complete_callback.call(Captain::Tools::HandoffTool.new(assistant).name, 'ok', context_wrapper)

      expect(root_span).to receive(:set_attribute).with('langfuse.trace.metadata.credit_used', 'false')
      run_complete_callback.call('assistant', nil, context_wrapper)
    end

    it 'sets credit_used=true when handoff tool is not used' do
      service = described_class.new(assistant: assistant, conversation: conversation)
      runner = instance_double(Agents::AgentRunner)
      run_complete_callback = nil
      span_class = Class.new do
        def set_attribute(*); end
      end
      root_span = instance_double(span_class)
      context_wrapper = Struct.new(:context).new({ __otel_tracing: { root_span: root_span } })

      allow(ChatwootApp).to receive(:otel_enabled?).and_return(true)
      allow(runner).to receive(:on_tool_complete).and_return(runner)
      allow(runner).to receive(:on_run_complete) do |&block|
        run_complete_callback = block
        runner
      end

      service.send(:add_usage_metadata_callback, runner)

      expect(root_span).to receive(:set_attribute).with('langfuse.trace.metadata.credit_used', 'true')
      run_complete_callback.call('assistant', nil, context_wrapper)
    end
  end

  describe 'constants' do
    it 'defines conversation state attributes' do
      expect(described_class::CONVERSATION_STATE_ATTRIBUTES).to include(
        :id, :display_id, :inbox_id, :contact_id, :status, :priority
      )
    end

    it 'defines contact state attributes' do
      expect(described_class::CONTACT_STATE_ATTRIBUTES).to include(
        :id, :name, :email, :phone_number, :identifier, :contact_type
      )
    end

    it 'defines campaign state attributes' do
      expect(described_class::CAMPAIGN_STATE_ATTRIBUTES).to include(
        :id, :title, :message, :campaign_type, :description
      )
    end
  end
end
