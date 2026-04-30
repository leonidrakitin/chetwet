# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::Llm::HandoffApprovalGeneratorService do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:service) { described_class.new(assistant: assistant, conversation: conversation, reason: 'refund', faq_snippets: ['Refund within 14 days']) }
  let(:chat_double) { instance_double(RubyLLM::Chat) }
  let(:response_double) { instance_double(RubyLLM::Message, content: response_payload) }

  before do
    allow(service).to receive(:chat).and_return(chat_double)
    allow(chat_double).to receive(:with_params).and_return(chat_double)
    allow(chat_double).to receive(:with_instructions).and_return(chat_double)
    allow(chat_double).to receive(:ask).and_return(response_double)

    conversation.messages.create!(
      account_id: account.id, inbox_id: inbox.id, sender: contact,
      message_type: :incoming, content: 'I want a refund please'
    )
  end

  context 'when the LLM returns valid JSON' do
    let(:response_payload) do
      { customer_message: 'Checking with the team', options: ['Refund approved', 'Need details'] }.to_json
    end

    it 'parses customer_message and options' do
      result = service.generate
      expect(result[:customer_message]).to eq('Checking with the team')
      expect(result[:options]).to eq(['Refund approved', 'Need details'])
    end

    it 'wraps the user-supplied instructions into the system prompt' do
      assistant.update!(config: assistant.config.merge('handoff_approval_instructions' => 'BE BRIEF'))
      expect(chat_double).to receive(:with_instructions).with(a_string_including('BE BRIEF')).and_return(chat_double)

      service.generate
    end

    it 'falls back to the default instructions when the assistant config is empty' do
      expect(chat_double).to receive(:with_instructions).with(
        a_string_including(described_class::DEFAULT_INSTRUCTIONS.strip)
      ).and_return(chat_double)

      service.generate
    end

    it 'includes FAQ snippets and recent messages in the user prompt' do
      expect(chat_double).to receive(:ask).with(
        a_string_including('Refund within 14 days').and(including('I want a refund please'))
      ).and_return(response_double)

      service.generate
    end
  end

  context 'when the LLM wraps JSON in markdown fences' do
    let(:response_payload) do
      "```json\n#{{ customer_message: 'ok', options: %w[a b] }.to_json}\n```"
    end

    it 'still parses correctly' do
      result = service.generate
      expect(result[:customer_message]).to eq('ok')
      expect(result[:options]).to eq(%w[a b])
    end
  end

  context 'when the LLM returns invalid JSON' do
    let(:response_payload) { 'not json at all' }

    it 'returns a blank result without raising' do
      expect(service.generate).to eq(customer_message: '', options: [])
    end
  end

  context 'when the LLM raises an error' do
    let(:response_payload) { '' }

    before do
      allow(chat_double).to receive(:ask).and_raise(RubyLLM::Error.new('boom'))
    end

    it 'returns a blank result' do
      expect(service.generate).to eq(customer_message: '', options: [])
    end
  end
end
