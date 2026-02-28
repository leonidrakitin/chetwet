# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConversationCleaner do
  describe '#clean' do
    let(:cleaner) { described_class.new }

    it 'filters out dialogs with fewer than 3 messages' do
      dialogs = [
        {
          external_id: '1',
          messages: [
            { sender_type: 'user', content: 'Hi', created_at: Time.current },
            { sender_type: 'agent', content: 'Hello', created_at: Time.current }
          ]
        }
      ]
      expect(cleaner.clean(dialogs)).to eq([])
    end

    it 'keeps dialogs with at least 3 messages and sufficient average length' do
      dialogs = [
        {
          external_id: '1',
          messages: [
            { sender_type: 'user', content: 'Hello, I need help with my order.', created_at: Time.current },
            { sender_type: 'agent', content: 'Sure, please share your order ID.', created_at: Time.current },
            { sender_type: 'user', content: 'It is #12345. Thank you!', created_at: Time.current }
          ]
        }
      ]
      result = cleaner.clean(dialogs)
      expect(result.size).to eq(1)
      expect(result.first[:external_id]).to eq('1')
    end

    it 'filters out dialogs with only system or bot senders' do
      dialogs = [
        {
          external_id: '1',
          messages: [
            { sender_type: 'system', content: 'System message one', created_at: Time.current },
            { sender_type: 'system', content: 'System message two', created_at: Time.current },
            { sender_type: 'system', content: 'System message three', created_at: Time.current }
          ]
        }
      ]
      expect(cleaner.clean(dialogs)).to eq([])
    end

    it 'filters out dialogs with very short average message length' do
      dialogs = [
        {
          external_id: '1',
          messages: [
            { sender_type: 'user', content: 'a', created_at: Time.current },
            { sender_type: 'agent', content: 'b', created_at: Time.current },
            { sender_type: 'user', content: 'c', created_at: Time.current }
          ]
        }
      ]
      expect(cleaner.clean(dialogs)).to eq([])
    end
  end
end
