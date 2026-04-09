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

  describe '#description' do
    it 'mentions escalation to human support' do
      expect(tool.description).to include('Escalate the conversation to the human support team')
    end
  end

  describe '#parameters' do
    it 'returns the correct parameters' do
      expect(tool.parameters).to have_key(:reason)
      expect(tool.parameters[:reason].name).to eq(:reason)
      expect(tool.parameters[:reason].type).to eq('string')
      expect(tool.parameters[:reason].description).to eq('The reason why human escalation is needed (optional)')
      expect(tool.parameters[:reason].required).to be false
      expect(tool.parameters).to have_key(:customer_message)
      expect(tool.parameters[:customer_message].required).to be false
      expect(tool.parameters).to have_key(:options)
      expect(tool.parameters[:options].required).to be false
      expect(tool.parameters).to have_key(:post_reason_as_note)
      expect(tool.parameters[:post_reason_as_note].required).to be false
    end
  end

  describe '#perform' do
    context 'when conversation exists' do
      context 'with reason provided' do
        it 'creates a private note with reason and hands off conversation' do
          reason = 'Customer needs specialized support'

          expect do
            result = tool.perform(tool_context, reason: reason)
            expect(result).to eq("Conversation escalated to human support team (Reason: #{reason})")
          end.to change(Message, :count).by(1)
        end

        it 'creates message with correct attributes' do
          reason = 'Customer needs specialized support'
          tool.perform(tool_context, reason: reason)

          private_message = conversation.messages.where(private: true).order(:created_at).last
          expect(private_message.content).to eq(reason)
          expect(private_message.message_type).to eq('outgoing')
          expect(private_message.private).to be true
          expect(private_message.sender).to eq(assistant)
          expect(private_message.account).to eq(account)
          expect(private_message.inbox).to eq(inbox)
          expect(private_message.conversation).to eq(conversation)
        end

        it 'triggers bot handoff on conversation' do
          # The tool finds the conversation by ID, so we need to mock the found conversation
          found_conversation = Conversation.find(conversation.id)
          scoped_conversations = Conversation.where(account_id: assistant.account_id)
          allow(Conversation).to receive(:where).with(account_id: assistant.account_id).and_return(scoped_conversations)
          allow(scoped_conversations).to receive(:find_by).with(id: conversation.id).and_return(found_conversation)
          expect(found_conversation).to receive(:bot_handoff!)

          tool.perform(tool_context, reason: 'Test reason')
        end

        it 'creates a conversation_bot_handoff reporting event' do
          create(:captain_inbox, captain_assistant: assistant, inbox: inbox)
          Current.executed_by = assistant

          perform_enqueued_jobs do
            tool.perform(tool_context, reason: 'Customer needs specialized support')
          end

          reporting_event = ReportingEvent.find_by(conversation_id: conversation.id, name: 'conversation_bot_handoff')
          expect(reporting_event).to be_present
        ensure
          Current.reset
        end

        it 'logs tool usage with reason' do
          reason = 'Customer needs help'
          expect(tool).to receive(:log_tool_usage).with(
            'tool_human_escalation',
            { conversation_id: conversation.id, reason: reason }
          )

          tool.perform(tool_context, reason: reason)
        end
      end

      context 'without reason provided' do
        it 'hands off conversation without sending a public message when no operator notified' do
          expect do
            result = tool.perform(tool_context)
            expect(result).to eq('Conversation escalated to human support team')
          end.not_to change(Message, :count)
        end

        it 'logs tool usage with default reason' do
          expect(tool).to receive(:log_tool_usage).with(
            'tool_human_escalation',
            { conversation_id: conversation.id, reason: 'Agent requested human escalation' }
          )

          tool.perform(tool_context)
        end
      end

      context 'when operator notification is available' do
        let(:user) { create(:user, account: account, telegram_chat_id: '1234') }

        before do
          conversation.update!(assignee: user)
        end

        it 'sends a public message with input options' do
          tool.perform(
            tool_context,
            reason: 'Needs operator approval',
            customer_message: 'I will check this with an operator and get back to you.',
            options: ['Approve cancellation', 'Deny cancellation']
          )

          outgoing = conversation.messages.outgoing.order(:created_at).last
          items = outgoing.content_attributes['items'] || outgoing.content_attributes[:items]
          titles = items.map { |item| item['title'] || item[:title] }

          expect(outgoing.content).to eq('I will check this with an operator and get back to you.')
          expect(outgoing.content_type).to eq('input_select')
          expect(titles).to include('Approve cancellation', 'Deny cancellation')
        end
      end

      context 'with post_reason_as_note: false' do
        it 'hands off without creating a private note (avoids duplicate when Add Private Note was already used)' do
          reason = 'Customer needs specialized support'

          expect do
            result = tool.perform(tool_context, reason: reason, post_reason_as_note: false)
            expect(result).to eq("Conversation escalated to human support team (Reason: #{reason})")
          end.not_to change(Message, :count)
        end

        it 'still triggers bot handoff' do
          conversation.reload
          expect(conversation).to receive(:bot_handoff!)

          tool.perform(tool_context, reason: 'Test', post_reason_as_note: false)
        end
      end

      context 'when handoff fails' do
        before do
          # Mock the conversation lookup and handoff failure
          found_conversation = Conversation.find(conversation.id)
          scoped_conversations = Conversation.where(account_id: assistant.account_id)
          allow(Conversation).to receive(:where).with(account_id: assistant.account_id).and_return(scoped_conversations)
          allow(scoped_conversations).to receive(:find_by).with(id: conversation.id).and_return(found_conversation)
          allow(found_conversation).to receive(:bot_handoff!).and_raise(StandardError, 'Handoff error')

          exception_tracker = instance_double(ChatwootExceptionTracker)
          allow(ChatwootExceptionTracker).to receive(:new).and_return(exception_tracker)
          allow(exception_tracker).to receive(:capture_exception)
        end

        it 'returns error message' do
          result = tool.perform(tool_context, reason: 'Test')
          expect(result).to eq('Failed to escalate conversation to human support')
        end

        it 'captures exception' do
          exception_tracker = instance_double(ChatwootExceptionTracker)
          expect(ChatwootExceptionTracker).to receive(:new).with(instance_of(StandardError)).and_return(exception_tracker)
          expect(exception_tracker).to receive(:capture_exception)

          tool.perform(tool_context, reason: 'Test')
        end
      end
    end

    context 'when conversation does not exist' do
      let(:tool_context) { Struct.new(:state).new({ conversation: { id: 999_999 } }) }

      it 'returns error message' do
        result = tool.perform(tool_context, reason: 'Test')
        expect(result).to eq('Conversation not found')
      end

      it 'does not create a message' do
        expect do
          tool.perform(tool_context, reason: 'Test')
        end.not_to change(Message, :count)
      end
    end

    context 'when conversation state is missing' do
      let(:tool_context) { Struct.new(:state).new({}) }

      it 'returns error message' do
        result = tool.perform(tool_context, reason: 'Test')
        expect(result).to eq('Conversation not found')
      end
    end

    context 'when conversation id is nil' do
      let(:tool_context) { Struct.new(:state).new({ conversation: { id: nil } }) }

      it 'returns error message' do
        result = tool.perform(tool_context, reason: 'Test')
        expect(result).to eq('Conversation not found')
      end
    end
  end

  describe '#active?' do
    it 'returns true for public tools' do
      expect(tool.active?).to be true
    end
  end

  describe 'out of office message after handoff' do
    context 'when outside business hours' do
      before do
        inbox.update!(
          working_hours_enabled: true,
          out_of_office_message: 'We are currently closed. Please leave your email.'
        )
        inbox.working_hours.find_by(day_of_week: Time.current.in_time_zone(inbox.timezone).wday).update!(
          closed_all_day: true,
          open_all_day: false
        )
      end

      it 'sends out of office message after handoff' do
        expect do
          tool.perform(tool_context, reason: 'Customer needs help')
        end.to change { conversation.messages.template.count }.by(1)

        ooo_message = conversation.messages.template.last
        expect(ooo_message.content).to eq('We are currently closed. Please leave your email.')
      end
    end

    context 'when within business hours' do
      before do
        inbox.update!(
          working_hours_enabled: true,
          out_of_office_message: 'We are currently closed.'
        )
        inbox.working_hours.find_by(day_of_week: Time.current.in_time_zone(inbox.timezone).wday).update!(
          open_all_day: true,
          closed_all_day: false
        )
      end

      it 'does not send out of office message after handoff' do
        expect do
          tool.perform(tool_context, reason: 'Customer needs help')
        end.not_to(change { conversation.messages.template.count })
      end
    end

    context 'when no out of office message is configured' do
      before do
        inbox.update!(
          working_hours_enabled: true,
          out_of_office_message: nil
        )
        inbox.working_hours.find_by(day_of_week: Time.current.in_time_zone(inbox.timezone).wday).update!(
          closed_all_day: true,
          open_all_day: false
        )
      end

      it 'does not send out of office message' do
        expect do
          tool.perform(tool_context, reason: 'Customer needs help')
        end.not_to(change { conversation.messages.template.count })
      end
    end
  end
end
