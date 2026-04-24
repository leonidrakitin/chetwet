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
end
