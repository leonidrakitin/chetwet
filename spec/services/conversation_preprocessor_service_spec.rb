# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConversationPreprocessorService do
  let(:account) { create(:account) }

  def dialogs(count)
    Array.new(count) { |i| { external_id: "d#{i}", messages: [{ sender_type: 'user', content: "msg #{i}" }] } }
  end

  describe '#preprocess' do
    it 'returns empty array for empty input' do
      service = described_class.new(account)
      expect(service.preprocess([])).to eq([])
    end

    it 'returns cleaned and deduplicated dialogs' do
      allow_any_instance_of(ConversationCleaner).to receive(:clean).and_return([{ messages: [] }])
      allow_any_instance_of(ConversationDeduplicator).to receive(:deduplicate).and_return([{ messages: [] }])

      service = described_class.new(account)
      result = service.preprocess(dialogs(3))
      expect(result).to eq([{ messages: [] }])
    end

    context 'stats tracking' do
      before do
        allow_any_instance_of(ConversationCleaner).to receive(:clean) { |_, d| d.first(3) }
        allow_any_instance_of(ConversationDeduplicator).to receive(:deduplicate) { |_, d| d.first(2) }
      end

      it 'sets stats[:total] equal to input size' do
        service = described_class.new(account)
        service.preprocess(dialogs(5))
        expect(service.stats[:total]).to eq(5)
      end

      it 'sets stats[:cleaned] = count filtered by cleaner' do
        service = described_class.new(account)
        service.preprocess(dialogs(5))
        # cleaner keeps 3 of 5 → cleaned = 2
        expect(service.stats[:cleaned]).to eq(2)
      end

      it 'sets stats[:deduplicated] = count filtered by deduplicator' do
        service = described_class.new(account)
        service.preprocess(dialogs(5))
        # deduplicator keeps 2 of 3 → deduplicated = 1
        expect(service.stats[:deduplicated]).to eq(1)
      end

      it 'sets stats[:kept] = final unique count' do
        service = described_class.new(account)
        service.preprocess(dialogs(5))
        expect(service.stats[:kept]).to eq(2)
      end
    end

    it '#report returns correct keys and values after preprocess' do
      allow_any_instance_of(ConversationCleaner).to receive(:clean).and_return(dialogs(2))
      allow_any_instance_of(ConversationDeduplicator).to receive(:deduplicate).and_return(dialogs(1))

      service = described_class.new(account)
      service.preprocess(dialogs(3))
      report = service.report

      expect(report).to include(
        processed: 3,
        skipped_as_spam_or_short: 1,
        duplicates_removed: 1,
        ready_for_import: 1
      )
    end
  end
end
