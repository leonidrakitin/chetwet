require 'rails_helper'

RSpec.describe Captain::AutoClassifyConversationJob do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:assistant) { create(:captain_assistant, account: account) }

  describe '#perform' do
    before do
      # Mock classification service
      allow_any_instance_of(Captain::AutoClassificationService).to receive(:classify).and_return(
        {
          department: 'support',
          priority: 'high',
          sentiment: 'negative',
          language: 'en',
          tags: %w[urgent billing],
          requires_immediate_response: true,
          suggested_response_template: 'faq_1'
        }
      )
    end

    it 'classifies conversation' do
      expect(Captain::AutoClassificationService).to receive(:new).and_call_original

      described_class.perform_now(
        conversation_id: conversation.id,
        assistant_id: assistant.id
      )
    end

    it 'applies classification to conversation' do
      described_class.perform_now(
        conversation_id: conversation.id,
        assistant_id: assistant.id
      )

      conversation.reload
      expect(conversation.priority).to eq('high')
    end

    it 'adds labels for department' do
      described_class.perform_now(
        conversation_id: conversation.id,
        assistant_id: assistant.id
      )

      conversation.reload
      expect(conversation.label_list).to include('department:support')
    end

    context 'with missing conversation' do
      it 'gracefully handles' do
        expect do
          described_class.perform_now(
            conversation_id: 99_999,
            assistant_id: assistant.id
          )
        end.not_to raise_error
      end
    end

    context 'with classification error' do
      before do
        allow_any_instance_of(Captain::AutoClassificationService).to receive(:classify).and_return(nil)
      end

      it 'handles gracefully' do
        expect do
          described_class.perform_now(
            conversation_id: conversation.id,
            assistant_id: assistant.id
          )
        end.not_to raise_error
      end
    end
  end
end
