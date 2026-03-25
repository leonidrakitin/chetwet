require 'rails_helper'

RSpec.describe Captain::AutoClassificationService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:service) { described_class.new(conversation: conversation, assistant: assistant) }

  describe '#classify' do
    context 'with valid conversation' do
      it 'returns classification result' do
        # Mock LLM response
        allow_any_instance_of(RubyLLM::Chat).to receive(:prompt).and_return(
          {
            department: 'support',
            priority: 'high',
            sentiment: 'negative',
            language: 'en',
            tags: ['billing_issue'],
            requires_immediate_response: true,
            suggested_response_template: 'billing_faq_1'
          }
        )

        result = service.classify
        expect(result).to be_a(Hash)
        expect(result[:department]).to eq('support')
        expect(result[:priority]).to eq('high')
      end
    end

    context 'with nil conversation' do
      let(:service) { described_class.new(conversation: nil, assistant: assistant) }

      it 'returns nil' do
        result = service.classify
        expect(result).to be_nil
      end
    end

    context 'with LLM error' do
      it 'gracefully handles error' do
        allow_any_instance_of(RubyLLM::Chat).to receive(:prompt).and_raise(StandardError, 'API error')

        result = service.classify
        expect(result).to be_nil
      end
    end
  end

  describe 'private methods' do
    describe '#build_classification_message' do
      it 'includes conversation context' do
        message = service.send(:build_classification_message)
        expect(message).to include('Customer message:')
        expect(message).to include('Conversation status:')
      end
    end

    describe '#map_priority_to_level' do
      it 'maps classification priority to conversation priority' do
        expect(service.send(:map_priority_to_level, 'urgent')).to eq('urgent')
        expect(service.send(:map_priority_to_level, 'low')).to eq('none')
      end
    end
  end
end
