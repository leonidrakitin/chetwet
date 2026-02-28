# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConversationDeduplicator, skip: !defined?(Captain::Llm::EmbeddingService) do
  let(:account) { create(:account) }

  before do
    embedding_service = instance_double(Captain::Llm::EmbeddingService, get_embedding: [0.1] * 256)
    allow(Captain::Llm::EmbeddingService).to receive(:new).with(account_id: account.id).and_return(embedding_service)
  end

  describe '#deduplicate' do
    it 'returns empty when dialogs is empty' do
      deduplicator = described_class.new(account)
      expect(deduplicator.deduplicate([])).to eq([])
    end

    it 'returns all dialogs when embeddings are different' do
      deduplicator = described_class.new(account)
      embedding_svc = Captain::Llm::EmbeddingService.new(account_id: account.id)
      allow(embedding_svc).to receive(:get_embedding).and_return([0.1] * 256, [0.9] * 256)
      allow(Captain::Llm::EmbeddingService).to receive(:new).with(account_id: account.id).and_return(embedding_svc)

      dialogs = [
        { messages: [{ sender_type: 'user', content: 'First dialog' }] },
        { messages: [{ sender_type: 'user', content: 'Second dialog' }] }
      ]
      result = deduplicator.deduplicate(dialogs)
      expect(result.size).to eq(2)
    end

    it 'returns one dialog when two produce same embedding' do
      same_embedding = [0.5] * 256
      embedding_svc = instance_double(Captain::Llm::EmbeddingService, get_embedding: same_embedding)
      allow(Captain::Llm::EmbeddingService).to receive(:new).with(account_id: account.id).and_return(embedding_svc)

      deduplicator = described_class.new(account)
      dialogs = [
        { messages: [{ sender_type: 'user', content: 'Same content' }] },
        { messages: [{ sender_type: 'user', content: 'Same content' }] }
      ]
      result = deduplicator.deduplicate(dialogs)
      expect(result.size).to eq(1)
    end
  end
end
