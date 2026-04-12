# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vk::OutgoingMessageSyncService do
  let!(:account) { create(:account) }
  let!(:channel_vk) { create(:channel_vk, account: account) }
  let!(:inbox) { channel_vk.inbox }
  let!(:contact) { create(:contact, account: account) }
  let!(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: '17213748') }
  let!(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
                          additional_attributes: { 'peer_id' => 17_213_748 })
  end

  let(:vk_user_info) do
    { 'first_name' => 'Test', 'last_name' => 'User', 'photo_100' => 'https://example.com/photo.jpg' }
  end

  before do
    allow(channel_vk).to receive(:get_vk_user_info).and_return(vk_user_info)
  end

  describe '#perform' do
    context 'when message has random_id from Chatwoot' do
      let!(:existing_message) do
        create(
          :message,
          :outgoing,
          conversation: conversation,
          account: account,
          inbox: inbox,
          content: 'Привет! Привет! Привет!',
          external_source_ids: { 'vk_random_id' => '351822384' },
          source_id: nil
        )
      end

      let(:webhook_params) do
        {
          date: 1_775_977_275,
          from_id: -225_520_986,
          id: 107,
          out: 1,
          conversation_message_id: 65,
          text: 'Привет! Привет! Привет!',
          peer_id: 17_213_748,
          random_id: 351_822_384
        }
      end

      it 'updates existing message source_id instead of creating duplicate' do
        expect do
          described_class.new(inbox: inbox, params: webhook_params).perform
        end.not_to change(Message, :count)

        existing_message.reload
        expect(existing_message.source_id).to eq('107')
      end

      it 'returns early after updating message by random_id' do
        service = described_class.new(inbox: inbox, params: webhook_params)
        expect(service).not_to receive(:create_outgoing_message)

        service.perform
      end
    end

    context 'when message is sent from VK admin interface (no random_id match)' do
      let(:webhook_params) do
        {
          date: 1_775_977_275,
          from_id: -225_520_986,
          id: 108,
          out: 1,
          conversation_message_id: 66,
          text: 'Сообщение из VK админки',
          peer_id: 17_213_748,
          random_id: 0
        }
      end

      it 'creates a new message with external_echo flag' do
        expect do
          described_class.new(inbox: inbox, params: webhook_params).perform
        end.to change(Message, :count).by(1)

        message = Message.last
        expect(message.source_id).to eq('108')
        expect(message.content_attributes['external_echo']).to be true
        expect(message.status).to eq('delivered')
      end
    end

    context 'when duplicate message already exists with same source_id' do
      let!(:existing_message) do
        create(
          :message,
          :outgoing,
          conversation: conversation,
          account: account,
          inbox: inbox,
          content: 'Уже существует',
          source_id: '107'
        )
      end

      let(:webhook_params) do
        {
          date: 1_775_977_275,
          from_id: -225_520_986,
          id: 107,
          out: 1,
          text: 'Дубликат',
          peer_id: 17_213_748,
          random_id: 351_822_384
        }
      end

      it 'does not create duplicate' do
        expect do
          described_class.new(inbox: inbox, params: webhook_params).perform
        end.not_to change(Message, :count)
      end
    end
  end
end
