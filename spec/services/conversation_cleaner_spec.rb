# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConversationCleaner do
  subject(:cleaner) { described_class.new }

  def dialog_with(messages:)
    { external_id: SecureRandom.hex(4), messages: messages }
  end

  def msg(sender_type, content, created_at: Time.current)
    { sender_type: sender_type, content: content, created_at: created_at }
  end

  describe '#clean' do
    it 'keeps a valid dialog with 3+ messages, both agent & user, avg length >= 10' do
      dialogs = [
        dialog_with(messages: [
                      msg('user', 'Hello, I need help with my order.'),
                      msg('agent', 'Sure, please share your order ID.'),
                      msg('user', 'It is #12345. Thank you very much!')
                    ])
      ]
      expect(cleaner.clean(dialogs).size).to eq(1)
    end

    it 'removes dialog with fewer than MIN_MESSAGES' do
      dialogs = [
        dialog_with(messages: [
                      msg('user', 'Hello there'),
                      msg('agent', 'Hi, how can I help?')
                    ])
      ]
      expect(cleaner.clean(dialogs)).to eq([])
    end

    it 'removes dialog where all senders are system' do
      dialogs = [
        dialog_with(messages: [
                      msg('system', 'System notification one'),
                      msg('system', 'System notification two'),
                      msg('system', 'System notification three')
                    ])
      ]
      expect(cleaner.clean(dialogs)).to eq([])
    end

    it 'removes dialog where all senders are bot' do
      dialogs = [
        dialog_with(messages: [
                      msg('bot', 'Automated message one'),
                      msg('bot', 'Automated message two'),
                      msg('bot', 'Automated message three')
                    ])
      ]
      expect(cleaner.clean(dialogs)).to eq([])
    end

    it 'removes dialog where avg message length is below threshold' do
      dialogs = [
        dialog_with(messages: [
                      msg('user', 'a'),
                      msg('agent', 'b'),
                      msg('user', 'c')
                    ])
      ]
      expect(cleaner.clean(dialogs)).to eq([])
    end

    it 'removes spam dialog where >70% messages are from one sender when agent is present' do
      dialogs = [
        dialog_with(messages: [
                      msg('user', 'Buy our product now, great deal!'),
                      msg('user', 'Buy our product now, great deal!'),
                      msg('user', 'Buy our product now, great deal!'),
                      msg('user', 'Buy our product now, great deal!'),
                      msg('user', 'Buy our product now, great deal!'),
                      msg('user', 'Buy our product now, great deal!'),
                      msg('user', 'Buy our product now, great deal!'),
                      msg('user', 'Buy our product now, great deal!'),
                      msg('agent', 'We do not send spam, sorry.')
                    ])
      ]
      expect(cleaner.clean(dialogs)).to eq([])
    end

    it 'keeps dialog without agent messages even with 100% user senders (anti-filter when no agent)' do
      dialogs = [
        dialog_with(messages: [
                      msg('user', 'First message from user here.'),
                      msg('user', 'Second message from user here.'),
                      msg('user', 'Third message from user here.')
                    ])
      ]
      expect(cleaner.clean(dialogs).size).to eq(1)
    end

    it 'removes spam_like? dialog when >75% of messages are very similar and count >= 4' do
      similar = 'Buy cheap meds online today.'
      dialogs = [
        dialog_with(messages: [
                      msg('user', similar),
                      msg('user', similar),
                      msg('user', similar),
                      msg('user', similar),
                      msg('agent', 'Hello, how can I assist you today?')
                    ])
      ]
      expect(cleaner.clean(dialogs)).to eq([])
    end

    it 'keeps dialog when similar messages count is below spam_like? threshold' do
      dialogs = [
        dialog_with(messages: [
                      msg('user', 'I have a question about my bill.'),
                      msg('agent', 'Sure, what is your account number?'),
                      msg('user', 'It is 123456789, please check it.'),
                      msg('agent', 'I can see the charges, let me explain them.')
                    ])
      ]
      expect(cleaner.clean(dialogs).size).to eq(1)
    end
  end
end
