require 'rails_helper'

RSpec.describe Captain::AutoClassifyConversationJob do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:assistant) { create(:captain_assistant, account: account) }

  describe '#perform' do
    let(:classification) do
      {
        department: 'support',
        priority: 'high',
        sentiment: 'negative',
        language: 'en',
        tags: %w[urgent billing],
        requires_immediate_response: true,
        suggested_response_template: 'faq_1'
      }
    end

    before do
      allow_any_instance_of(Captain::AutoClassificationService).to receive(:classify).and_return(classification)
    end

    it 'classifies conversation' do
      expect_any_instance_of(Captain::AutoClassificationService).to receive(:classify).and_return(classification)

      described_class.perform_now(
        conversation_id: conversation.id,
        assistant_id: assistant.id
      )
    end

    it 'applies priority to conversation' do
      described_class.perform_now(
        conversation_id: conversation.id,
        assistant_id: assistant.id
      )

      conversation.reload
      expect(conversation.priority).to eq('high')
    end

    it 'stores classification metadata' do
      described_class.perform_now(
        conversation_id: conversation.id,
        assistant_id: assistant.id
      )

      conversation.reload
      classification_data = conversation.additional_attributes['auto_classification']
      expect(classification_data['department']).to eq('support')
      expect(classification_data['sentiment']).to eq('negative')
    end

    context 'with missing conversation' do
      it 'does not raise error' do
        expect do
          described_class.perform_now(conversation_id: 99_999, assistant_id: assistant.id)
        end.not_to raise_error
      end
    end

    context 'with classification error' do
      before do
        allow_any_instance_of(Captain::AutoClassificationService).to receive(:classify).and_return(nil)
      end

      it 'does not raise error' do
        expect do
          described_class.perform_now(conversation_id: conversation.id, assistant_id: assistant.id)
        end.not_to raise_error
      end
    end
  end
end
