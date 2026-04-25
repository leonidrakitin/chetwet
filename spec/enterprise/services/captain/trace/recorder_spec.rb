require 'rails_helper'

RSpec.describe Captain::Trace::Recorder do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:message) do
    create(:message, conversation: conversation, account: account, inbox: inbox,
                     message_type: :outgoing, sender: assistant, content: 'Done')
  end

  describe '#enabled?' do
    it 'is false when the feature flag is off' do
      instance = described_class.new(conversation: conversation, assistant: assistant)
      expect(instance.enabled?).to be(false)
    end

    it 'is true when the feature flag is on' do
      account.enable_features!('captain_trace_events')
      instance = described_class.new(conversation: conversation, assistant: assistant)
      expect(instance.enabled?).to be(true)
    end
  end

  describe '#record and #flush_to' do
    before { account.enable_features!('captain_trace_events') }

    it 'persists buffered events with an incrementing sequence and the source message id' do
      instance = described_class.new(conversation: conversation, assistant: assistant)
      instance.record(:run_started, { v2: true })
      instance.record(:outgoing_message, { content: 'ok' })
      instance.record(:run_completed)

      expect { instance.flush_to(source_message: message) }.to change(Captain::TraceEvent, :count).by(3)

      events = Captain::TraceEvent.for_conversation(conversation.id).ordered
      expect(events.map(&:event_type)).to eq(%w[run_started outgoing_message run_completed])
      expect(events.map(&:sequence)).to eq([1, 2, 3])
      expect(events.map(&:source_message_id).uniq).to eq([message.id])
      expect(events.map(&:session_id).uniq.size).to eq(1)
    end

    it 'redacts emails and phone numbers in payload strings' do
      instance = described_class.new(conversation: conversation, assistant: assistant)
      instance.record(:llm_request, { content: 'Reach me at foo@bar.com or +1 415 555 9876' })
      instance.flush_to(source_message: message)

      event = Captain::TraceEvent.for_conversation(conversation.id).last
      expect(event.payload['content']).to include('[redacted_email]')
      expect(event.payload['content']).to include('[redacted_phone]')
    end

    it 'truncates oversized payloads' do
      stub_const("#{described_class}::MAX_PAYLOAD_BYTES", 64)
      instance = described_class.new(conversation: conversation, assistant: assistant)
      instance.record(:llm_request, { content: 'x' * 1024 })
      instance.flush_to(source_message: message)

      event = Captain::TraceEvent.for_conversation(conversation.id).last
      expect(event.payload['truncated']).to be(true)
      expect(event.payload['size_bytes']).to be > 64
    end
  end

  describe 'noop when disabled' do
    it 'does not persist anything even after flush' do
      instance = described_class.new(conversation: conversation, assistant: assistant)
      instance.record(:run_started)
      expect { instance.flush_to(source_message: message) }.not_to change(Captain::TraceEvent, :count)
    end
  end

  describe '#record_decision' do
    before { account.enable_features!('captain_trace_events') }

    it 'persists a decision_selected event with structured payload' do # rubocop:disable RSpec/MultipleExpectations
      instance = described_class.new(conversation: conversation, assistant: assistant)
      instance.record_decision(
        :decision_selected,
        domain: 'delayed_send',
        name: 'schedule_outbound_message',
        selected: true,
        reasoning_summary: 'Customer asked for follow-up tomorrow',
        scheduled_for: '2026-04-26T09:00:00Z',
        delay_seconds: 60 * 60 * 24,
        template_id: '42',
        template_name: 'Tomorrow nudge',
        correlation_id: 'abc123'
      )
      instance.flush_to(source_message: message)

      event = Captain::TraceEvent.for_conversation(conversation.id).last
      expect(event.event_type).to eq('decision_selected')
      payload = event.payload
      expect(payload['decision_domain']).to eq('delayed_send')
      expect(payload['decision_name']).to eq('schedule_outbound_message')
      expect(payload['selected']).to be(true)
      expect(payload['scheduled_for']).to eq('2026-04-26T09:00:00Z')
      expect(payload['delay_seconds']).to eq(86_400)
      expect(payload['template_id']).to eq('42')
      expect(payload['template_name']).to eq('Tomorrow nudge')
      expect(payload['correlation_id']).to eq('abc123')
    end

    it 'truncates long reasoning summaries' do
      stub_const("#{described_class}::MAX_REASONING_CHARS", 20)
      instance = described_class.new(conversation: conversation, assistant: assistant)
      instance.record_decision(
        :decision_evaluated, domain: 'tool_choice', name: 'foo',
                             reasoning_summary: 'x' * 1_000
      )
      instance.flush_to(source_message: message)
      event = Captain::TraceEvent.for_conversation(conversation.id).last
      expect(event.payload['reasoning_summary'].length).to be <= 20
    end
  end

  describe '#record_knowledge_hit' do
    before { account.enable_features!('captain_trace_events') }

    it 'persists a knowledge_hit event with source/score/snippet' do
      instance = described_class.new(conversation: conversation, assistant: assistant)
      instance.record_knowledge_hit(
        source: 'faq_lookup', query: 'refund', score: 0.92,
        reference: [{ 'label' => '1', 'title' => 'Refund policy' }],
        snippet: 'You can request a refund within 14 days.',
        extra: { policy: 'answer' }
      )
      instance.flush_to(source_message: message)

      event = Captain::TraceEvent.for_conversation(conversation.id).last
      expect(event.event_type).to eq('knowledge_hit')
      payload = event.payload
      expect(payload['source']).to eq('faq_lookup')
      expect(payload['score']).to eq(0.92)
      expect(payload['policy']).to eq('answer')
    end
  end

  describe 'timing helpers' do
    before { account.enable_features!('captain_trace_events') }

    it 'measures duration of a block and records duration_ms' do
      instance = described_class.new(conversation: conversation, assistant: assistant)
      instance.measure(:llm_response, { agent: 'orchestrator' }, correlation_id: 'c1') { sleep(0.01) }
      instance.flush_to(source_message: message)

      event = Captain::TraceEvent.for_conversation(conversation.id).last
      expect(event.event_type).to eq('llm_response')
      expect(event.payload['duration_ms']).to be_a(Integer)
      expect(event.payload['correlation_id']).to eq('c1')
    end

    it 'records run_duration_ms based on run_started event' do
      instance = described_class.new(conversation: conversation, assistant: assistant)
      instance.record(:run_started, {})
      sleep(0.01)
      expect(instance.run_duration_ms).to be >= 5
    end
  end
end
