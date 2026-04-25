require 'rails_helper'

RSpec.describe Captain::Trace::CleanupJob, type: :job do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:assistant) { create(:captain_assistant, account: account) }

  def create_event(created_at:, sequence: 1, session: 'sess')
    Captain::TraceEvent.create!(
      account: account, conversation: conversation, assistant: assistant,
      session_id: session, sequence: sequence,
      event_type: 'run_started', payload: { 'v2' => true },
      created_at: created_at
    )
  end

  describe '#perform' do
    it 'removes events older than the configured TTL and keeps fresh rows' do
      old_event = create_event(created_at: 60.days.ago)
      fresh_event = create_event(created_at: 1.day.ago, sequence: 2)
      allow(GlobalConfigService).to receive(:load).with('CAPTAIN_TRACE_TTL_DAYS', described_class::DEFAULT_TTL_DAYS).and_return(30)

      expect { described_class.perform_now }.to change(Captain::TraceEvent, :count).by(-1)
      expect(Captain::TraceEvent.where(id: old_event.id)).to be_empty
      expect(Captain::TraceEvent.where(id: fresh_event.id)).to be_present
    end

    it 'falls back to default TTL when config is zero or missing' do
      old_event = create_event(created_at: 60.days.ago)
      allow(GlobalConfigService).to receive(:load).with('CAPTAIN_TRACE_TTL_DAYS', described_class::DEFAULT_TTL_DAYS).and_return(0)

      expect { described_class.perform_now }.to change(Captain::TraceEvent, :count).by(-1)
      expect(Captain::TraceEvent.where(id: old_event.id)).to be_empty
    end

    it 'is a no-op when TTL is negative (cleanup disabled)' do
      create_event(created_at: 60.days.ago)
      allow(GlobalConfigService).to receive(:load).with('CAPTAIN_TRACE_TTL_DAYS', described_class::DEFAULT_TTL_DAYS).and_return(-1)

      expect { described_class.perform_now }.not_to change(Captain::TraceEvent, :count)
    end

    it 'deletes in batches and stops after MAX_BATCHES_PER_RUN' do
      stub_const("#{described_class}::BATCH_SIZE", 2)
      stub_const("#{described_class}::MAX_BATCHES_PER_RUN", 2)
      5.times { |i| create_event(created_at: 60.days.ago, sequence: i + 1, session: "sess_#{i}") }
      allow(GlobalConfigService).to receive(:load).and_return(30)

      expect { described_class.perform_now }.to change(Captain::TraceEvent, :count).by(-4)
    end
  end
end
