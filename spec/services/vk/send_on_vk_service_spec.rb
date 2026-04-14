# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vk::SendOnVkService do
  let!(:account) { create(:account) }
  let!(:channel_vk) { create(:channel_vk, account: account) }
  let!(:inbox) { channel_vk.inbox }
  let!(:contact) { create(:contact, account: account) }
  let!(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: '17213748') }
  let!(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
                          additional_attributes: { 'peer_id' => 17_213_748 })
  end

  let(:message) do
    create(:message, :outgoing, conversation: conversation, account: account, inbox: inbox, content: 'Test message')
  end

  before do
    allow(channel_vk).to receive(:send_message_on_vk).and_return({ message_id: 123, random_id: 456_789 })
  end

  describe '#perform' do
    it 'pre-persists vk_random_id and stores message_id after send' do
      expect(channel_vk).to receive(:send_message_on_vk) do |outgoing_message, random_id:|
        expect(outgoing_message.reload.external_source_ids['vk_random_id']).to eq(random_id.to_s)
        { message_id: 123, random_id: random_id }
      end

      described_class.new(message: message).perform

      message.reload
      expect(message.source_id).to eq('123')
      expect(message.external_source_ids['vk_random_id']).to be_present
    end

    it 'preserves existing external_source_ids when adding vk_random_id' do
      message.update!(external_source_ids: { 'other_id' => 'existing' })

      described_class.new(message: message).perform

      message.reload
      expect(message.external_source_ids['vk_random_id']).to eq('456789')
      expect(message.external_source_ids['other_id']).to eq('existing')
    end

    it 'reuses an existing vk_random_id instead of generating a new one' do
      message.update!(external_source_ids: { 'vk_random_id' => '111222', 'other_id' => 'existing' })

      expect(channel_vk).to receive(:send_message_on_vk).with(message, random_id: 111_222)
                                                        .and_return({ message_id: 123, random_id: 111_222 })

      described_class.new(message: message).perform

      expect(message.reload.external_source_ids).to eq(
        'vk_random_id' => '111222',
        'other_id' => 'existing'
      )
    end
  end
end
