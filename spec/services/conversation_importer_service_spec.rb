# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConversationImporterService do
  subject(:service) { described_class.new(inbox, assistant) }

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assistant) { create(:captain_assistant, account: account) }

  let(:dialog) do
    {
      external_id: 'ext-1',
      source: 'telegram',
      contact_external_id: 'user-42',
      contact_name: 'Test User',
      title: 'Test Chat',
      messages: [
        { external_id: 'm1', created_at: 2.hours.ago, sender_type: 'user', content: 'Hello there', content_type: 'text' },
        { external_id: 'm2', created_at: 1.hour.ago, sender_type: 'agent', content: 'Hi, how can I help?', content_type: 'text' }
      ]
    }
  end

  describe '#import!' do
    it 'creates Contact, ContactInbox, Conversation and Messages' do
      result = service.import!(dialog)

      expect(result[:success]).to be true
      expect(result[:conversation_id]).to be_a(Integer)

      conversation = Conversation.find(result[:conversation_id])
      expect(conversation.contact).to be_present
      expect(conversation.contact_inbox).to be_present
      expect(conversation.messages.count).to eq(dialog[:messages].size)
    end

    it 'returns { success: true, conversation_id: Integer, faqs_generated: 0 }' do
      result = service.import!(dialog)

      expect(result).to include(success: true, faqs_generated: 0)
      expect(result[:conversation_id]).to be_a(Integer)
    end

    it 'sets conversation status to :resolved after import' do
      result = service.import!(dialog)
      conversation = Conversation.find(result[:conversation_id])
      expect(conversation.status).to eq('resolved')
    end

    it 'stores imported_from and migration_external_id in additional_attributes' do
      result = service.import!(dialog)
      attrs = Conversation.find(result[:conversation_id]).additional_attributes
      expect(attrs['imported_from']).to eq('telegram')
      expect(attrs['migration_external_id']).to eq('ext-1')
    end

    it 'creates exactly as many messages as in dialog[:messages]' do
      result = service.import!(dialog)
      conversation = Conversation.find(result[:conversation_id])
      expect(conversation.messages.count).to eq(2)
    end

    it 'finds existing contact if the same source_id is used (idempotent contact creation)' do
      result1 = service.import!(dialog)
      result2 = service.import!(dialog.merge(external_id: 'ext-2'))

      contact1 = Conversation.find(result1[:conversation_id]).contact
      contact2 = Conversation.find(result2[:conversation_id]).contact
      expect(contact1.id).to eq(contact2.id)
    end

    it 'returns { success: false, error: } on RecordInvalid' do
      allow_any_instance_of(Inbox).to receive(:conversations).and_raise(ActiveRecord::RecordInvalid)
      result = service.import!(dialog)
      expect(result[:success]).to be false
      expect(result[:error]).to be_present
    end
  end
end
