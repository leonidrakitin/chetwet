# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::Tools::HandoffTool, type: :model do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:tool) { described_class.new(assistant) }
  let(:user) { create(:user, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:tool_context) { Struct.new(:state).new({ conversation: { id: conversation.id } }) }
  let(:generator_double) do
    instance_double(
      Captain::Llm::HandoffApprovalGeneratorService,
      generate: { customer_message: 'Hold on, checking with team', options: ['Approve cancellation', 'Deny cancellation'] }
    )
  end

  before do
    allow(Captain::Llm::HandoffApprovalGeneratorService).to receive(:new).and_return(generator_double)
  end

  describe '#description' do
    it 'mentions escalation to human support' do
      expect(tool.description).to include('Escalate the conversation to the human support team')
    end
  end

  describe '#parameters' do
    it 'returns the expected parameters' do
      expect(tool.parameters).to include(:reason, :customer_message, :options, :post_reason_as_note)
      expect(tool.parameters[:reason].required).to be false
    end
  end

  describe '#perform' do
    context 'when conversation does not exist' do
      let(:tool_context) { Struct.new(:state).new({ conversation: { id: 999_999 } }) }

      it 'returns error message and creates no messages' do
        expect do
          expect(tool.perform(tool_context, reason: 'Test')).to eq('Conversation not found')
        end.not_to change(Message, :count)
      end
    end

    context 'when handoff fails' do
      before do
        scoped = Conversation.where(account_id: assistant.account_id)
        allow(Conversation).to receive(:where).with(account_id: assistant.account_id).and_return(scoped)
        allow(scoped).to receive(:find_by).with(id: conversation.id).and_return(conversation)
        allow(conversation).to receive(:bot_handoff!).and_raise(StandardError, 'Handoff error')
        allow(ChatwootExceptionTracker).to receive(:new).and_return(instance_double(ChatwootExceptionTracker, capture_exception: nil))
      end

      it 'returns the failure message' do
        expect(tool.perform(tool_context, reason: 'Test')).to eq('Failed to escalate conversation to human support')
      end
    end

    context 'when approval is enabled (default) and assignee has no Telegram' do
      before do
        conversation.update!(assignee: user)
      end

      it 'creates an approval request and sends a plain customer message' do
        expect do
          tool.perform(tool_context, reason: 'Refund question')
        end.to change(Captain::ApprovalRequest, :count).by(1)

        request = Captain::ApprovalRequest.last
        expect(request.assignee_type).to eq('user')
        expect(request.assignee_id).to eq(user.id)
        labels = request.options.map { |o| o[:label] || o['label'] }
        expect(labels).to include('Approve cancellation', 'Deny cancellation')
        expect(labels.last).to eq(I18n.t('approval_bot.suggest_your_own'))
      end

      it 'sends a public text message to the customer (no input_select)' do
        tool.perform(tool_context, reason: 'Refund question')

        public_outgoing = conversation.messages.outgoing.where(private: false).order(:created_at).last
        expect(public_outgoing.content).to eq('Hold on, checking with team')
        expect(public_outgoing.content_type).not_to eq('input_select')
        expect(public_outgoing.content_attributes['approval_request_id']).to be_nil
      end

      it 'creates a private outgoing input_select that carries approval_request_id for the dashboard' do
        tool.perform(tool_context, reason: 'Refund question')
        request = Captain::ApprovalRequest.last

        private_select = conversation.messages.outgoing.where(private: true, content_type: 'input_select').last
        expect(private_select).to be_present
        expect(private_select.content_attributes['approval_request_id']).to eq(request.id)
      end

      it 'enqueues the NotifyJob even though the operator has no Telegram' do
        expect { tool.perform(tool_context, reason: 'Refund question') }
          .to have_enqueued_job(ApprovalBot::NotifyJob)
      end
    end

    context 'when approval is enabled and assignee has Telegram' do
      let(:user) { create(:user, account: account, telegram_chat_id: '1234') }

      before { conversation.update!(assignee: user) }

      it 'creates the approval request and enqueues the NotifyJob' do
        expect { tool.perform(tool_context, reason: 'Refund question') }
          .to change(Captain::ApprovalRequest, :count).by(1)
          .and have_enqueued_job(ApprovalBot::NotifyJob)
      end
    end

    context 'when approval is enabled and the conversation has a team but no assignee' do
      let(:team) { create(:team, account: account) }

      before { conversation.update!(team: team) }

      it 'creates the approval request targeting the team' do
        tool.perform(tool_context, reason: 'Refund question')

        request = Captain::ApprovalRequest.last
        expect(request.assignee_type).to eq('team')
        expect(request.assignee_id).to eq(team.id)
      end
    end

    context 'when approval is disabled in the assistant config' do
      before do
        assistant.update!(config: assistant.config.merge('handoff_approval_enabled' => false))
      end

      it 'does not create an approval request, sends no holding message, and still hands off' do
        expect do
          tool.perform(tool_context, reason: 'Customer needs help')
        end.not_to change(Captain::ApprovalRequest, :count)

        public_outgoing = conversation.messages.outgoing.where(private: false).order(:created_at).last
        # Only the private note with the reason is created, not a holding message.
        expect(public_outgoing).to be_nil
        expect(conversation.reload.status).to eq('open')
      end

      it 'does not call the LLM generator' do
        tool.perform(tool_context, reason: 'Customer needs help')
        expect(Captain::Llm::HandoffApprovalGeneratorService).not_to have_received(:new)
      end
    end

    context 'when handoff posts reason as private note' do
      it 'creates a private note and triggers bot_handoff! once' do
        scoped = Conversation.where(account_id: assistant.account_id)
        allow(Conversation).to receive(:where).with(account_id: assistant.account_id).and_return(scoped)
        allow(scoped).to receive(:find_by).with(id: conversation.id).and_return(conversation)
        expect(conversation).to receive(:bot_handoff!).and_call_original

        expect do
          tool.perform(tool_context, reason: 'Refund question')
        end.to change { conversation.messages.where(private: true).count }.by_at_least(1)
      end

      it 'omits the private note when post_reason_as_note is false' do
        expect do
          tool.perform(tool_context, reason: 'Refund question', post_reason_as_note: false)
        end.not_to(change { conversation.messages.where(private: true, content: 'Refund question').count })
      end
    end

    context 'when LLM args override the generated values' do
      before { conversation.update!(assignee: user) }

      it 'uses the explicit customer_message and options from the orchestrator' do
        tool.perform(
          tool_context,
          reason: 'Custom override',
          customer_message: "I'll check with my colleague",
          options: ['Yes refund', 'No refund']
        )

        public_outgoing = conversation.messages.outgoing.where(private: false).order(:created_at).last
        expect(public_outgoing.content).to eq("I'll check with my colleague")

        request = Captain::ApprovalRequest.last
        labels = request.options.map { |o| o[:label] || o['label'] }
        expect(labels).to include('Yes refund', 'No refund')
      end
    end
  end

  describe 'out of office message after handoff' do
    before { conversation.update!(assignee: user) }

    context 'when outside business hours' do
      before do
        inbox.update!(working_hours_enabled: true, out_of_office_message: 'We are currently closed.')
        inbox.working_hours.find_by(day_of_week: Time.current.in_time_zone(inbox.timezone).wday).update!(
          closed_all_day: true, open_all_day: false
        )
      end

      it 'sends out of office message after handoff' do
        expect do
          tool.perform(tool_context, reason: 'Customer needs help')
        end.to change { conversation.messages.template.count }.by(1)
      end
    end
  end
end
