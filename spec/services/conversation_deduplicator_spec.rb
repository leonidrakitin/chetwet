# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConversationDeduplicator, skip: !defined?(Captain::Llm::EmbeddingService) do
  let(:account) { create(:account) }
  let(:embedding_service) { instance_double(Captain::Llm::EmbeddingService) }

  before do
    allow(Captain::Llm::EmbeddingService).to receive(:new).with(account_id: account.id).and_return(embedding_service)
  end

  def make_dialog(content)
    { messages: [{ sender_type: 'user', content: content }] }
  end

  describe '#deduplicate' do
    it 'returns [] for empty input' do
      deduplicator = described_class.new(account)
      expect(deduplicator.deduplicate([])).to eq([])
    end

    it 'returns all dialogs when embeddings are dissimilar (cosine distance >= 0.22)' do
      # Two orthogonal-ish vectors will have cosine distance close to 1.0
      vec_a = [1.0] + ([0.0] * 255)
      vec_b = [0.0, 1.0] + ([0.0] * 254)
      allow(embedding_service).to receive(:get_embedding).and_return(vec_a, vec_b)

      deduplicator = described_class.new(account)
      dialogs = [make_dialog('First unique dialog'), make_dialog('Second unique dialog')]
      result = deduplicator.deduplicate(dialogs)
      expect(result.size).to eq(2)
    end

    it 'removes dialog when its embedding is similar to a previously seen one (distance < 0.22)' do
      # Identical embeddings → cosine distance = 0.0
      same_vec = [0.5] * 256
      allow(embedding_service).to receive(:get_embedding).and_return(same_vec, same_vec)

      deduplicator = described_class.new(account)
      dialogs = [make_dialog('Same content here'), make_dialog('Same content here')]
      result = deduplicator.deduplicate(dialogs)
      expect(result.size).to eq(1)
      expect(result.first).to eq(dialogs.first)
    end

    it 'skips dialog when message text is blank (no embedding generated)' do
      allow(embedding_service).to receive(:get_embedding).and_return([0.1] * 256)

      deduplicator = described_class.new(account)
      # First dialog has empty messages → blank text → skipped
      dialogs = [
        { messages: [] },
        make_dialog('Second unique dialog content')
      ]
      result = deduplicator.deduplicate(dialogs)
      expect(result.size).to eq(1)
      expect(result.first).to eq(dialogs.last)
    end
  end

  describe 'cosine_distance math' do
    let(:deduplicator) { described_class.new(account) }

    it 'computes distance of 0.0 for identical vectors' do
      vec = [1.0, 0.0, 0.0]
      distance = deduplicator.send(:cosine_distance, vec, vec)
      expect(distance).to be_within(0.0001).of(0.0)
    end

    it 'computes distance of 1.0 for orthogonal vectors' do
      vec_a = [1.0, 0.0, 0.0]
      vec_b = [0.0, 1.0, 0.0]
      distance = deduplicator.send(:cosine_distance, vec_a, vec_b)
      expect(distance).to be_within(0.0001).of(1.0)
    end

    it 'returns 1.0 for zero-norm vectors' do
      zero = [0.0, 0.0, 0.0]
      distance = deduplicator.send(:cosine_distance, zero, [1.0, 0.0, 0.0])
      expect(distance).to eq(1.0)
    end
  end
end
