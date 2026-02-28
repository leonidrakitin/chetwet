# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConversationPreprocessorService do
  let(:account) { create(:account) }

  describe '#preprocess' do
    it 'returns empty when dialogs is empty' do
      service = described_class.new(account)
      expect(service.preprocess([])).to eq([])
    end

    it 'returns cleaned and deduplicated dialogs' do
      allow_any_instance_of(ConversationCleaner).to receive(:clean).and_return([{ messages: [] }])
      allow_any_instance_of(ConversationDeduplicator).to receive(:deduplicate).and_return([{ messages: [] }])

      service = described_class.new(account)
      dialogs = [{ messages: [{ sender_type: 'user', content: 'Hi' }] }]
      result = service.preprocess(dialogs)
      expect(result).to eq([{ messages: [] }])
    end

    it 'exposes report with processed and kept counts' do
      allow_any_instance_of(ConversationCleaner).to receive(:clean).and_return([{ messages: [] }])
      allow_any_instance_of(ConversationDeduplicator).to receive(:deduplicate).and_return([{ messages: [] }])

      service = described_class.new(account)
      service.preprocess([{ messages: [] }, { messages: [] }])
      report = service.report
      expect(report).to include(:processed, :skipped_as_spam_or_short, :duplicates_removed, :ready_for_import)
      expect(report[:processed]).to eq(2)
      expect(report[:ready_for_import]).to eq(1)
    end
  end
end
