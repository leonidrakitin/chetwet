# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConversationImporterService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assistant) { create(:captain_assistant, account: account) }

  let(:unified_dialog) do
    {
      external_id: "import_#{SecureRandom.hex(4)}",
      source: 'telegram',
      contact_external_id: "user_#{SecureRandom.hex(4)}",
      contact_name: 'Test User',
      title: 'Test Chat',
      messages: [
        { external_id: 'msg1', sender_type: 'user', content: 'Hello', created_at: 1.day.ago, content_type: 'text' },
        { external_id: 'msg2', sender_type: 'agent', content: 'Hi there', created_at: 1.day.ago + 1.minute, content_type: 'text' }
      ]
    }
  end

  describe '#import!' do
    it 'creates a contact, conversation and messages' do
      service = described_class.new(inbox, assistant)
      result = service.import!(unified_dialog)

      expect(result[:success]).to be true
      expect(result[:conversation_id]).to be_present
      expect(result[:contact_id]).to be_present

      conversation = Conversation.find(result[:conversation_id])
      expect(conversation.status).to eq('resolved')
      expect(conversation.additional_attributes['imported']).to be true
      expect(conversation.messages.count).to eq(2)
    end

    it 'returns a result hash with success and conversation_id' do
      service = described_class.new(inbox, assistant)
      result = service.import!(unified_dialog)
      expect(result).to include(:success, :conversation_id, :contact_id)
      expect(result[:success]).to be true
    end
  end
end
