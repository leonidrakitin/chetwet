# frozen_string_literal: true

require 'rails_helper'

# Integration-level tests for the ask_human flow.
# These tests verify that the right tools are called given specific FAQ content
# by running the actual agent pipeline with mocked LLM responses and real DB records.
# rubocop:disable RSpec/DescribeClass, RSpec/AnyInstance, RSpec/ExpectInHook
RSpec.describe 'Captain ask_human tool flow', type: :integration do
  let(:account) { create(:account) }
  let(:decision_maker) { create(:user, account: account, telegram_chat_id: '123456789') }
  let(:assistant) do
    create(:captain_assistant, account: account, config: {
             'decision_maker_ids' => [decision_maker.id]
           })
  end
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  # Stub out embedding and notification side-effects globally for this file
  before do
    ic = InstallationConfig.find_or_initialize_by(name: 'CAPTAIN_OPEN_AI_API_KEY')
    ic.value = 'test-key'
    ic.save!

    embedding_service = instance_double(Captain::Llm::EmbeddingService)
    allow(Captain::Llm::EmbeddingService).to receive(:new).and_return(embedding_service)
    allow(embedding_service).to receive(:get_embedding).and_return(Array.new(1024, 0.1))

    # Stub ConversationSummarizerService used by ask_human to build context (avoids LLM calls)
    summarizer = instance_double(Captain::ConversationSummarizerService)
    allow(Captain::ConversationSummarizerService).to receive(:new).and_return(summarizer)
    allow(summarizer).to receive(:call).and_return({ summary: 'Клиент хочет помощи', recent_messages: [] })

    # Prevent actual Telegram/bot notifications
    allow(ApprovalBot::NotifyJob).to receive(:perform_later)

    # Disable autonomy retries to keep test focused on single-turn behavior
    allow(assistant).to receive(:autonomy_max_retries).and_return(0)
  end

  # ---------------------------------------------------------------------------
  # Case 1: FAQ with requires_clarification triggers ask_human
  # ---------------------------------------------------------------------------
  describe 'FAQ with Require operator clarification before replying = true' do
    let!(:faq_response) do
      create(:captain_assistant_response,
             assistant: assistant,
             question: 'Отмена заказа',
             answer: 'Давай отменим, но прежде уточним причину?',
             status: 'approved',
             requires_clarification: true)
    end

    before do
      # Return our specific FAQ as the search result
      allow(Captain::AssistantResponse).to receive(:nearest_neighbors).and_return(
        Captain::AssistantResponse.where(id: faq_response.id)
      )

      # Simulate LLM calling faq_lookup first, then ask_human.
      # We need to intercept Agents::Runner#run and make it:
      # 1. Call faq_lookup (real implementation runs, returns the clarification hint)
      # 2. Then call ask_human (real implementation creates ApprovalRequest)
      # 3. Return a non-handoff response so ResponseBuilderJob doesn't send a customer message.
      #
      # We do this by stubbing runner.run to directly call the tools in order.
      allow_any_instance_of(Agents::Runner).to receive(:run) do |_runner, _input, **kwargs|
        context = kwargs.fetch(:context)
        # Execute real faq_lookup — we want to verify it appends the clarification hint
        faq_tool = Captain::Tools::FaqLookupTool.new(assistant)
        tool_ctx = Struct.new(:state).new(context[:state])
        faq_result = faq_tool.perform(tool_ctx, query: 'Хочу отменить заказ')

        expect(faq_result).to include('[REQUIRES_OPERATOR_CLARIFICATION')

        # Execute real ask_human — it creates an ApprovalRequest and enqueues NotifyJob
        ask_human_tool = Captain::Tools::AskHumanTool.new(assistant)
        ask_human_tool.perform(
          tool_ctx,
          title: 'Клиент хочет отменить заказ. Подтвердите уточняющий ответ.'
        )

        Struct.new(:output, :context).new(
          { 'response' => 'Уточняю с оператором', 'reasoning' => 'clarification required' },
          context
        )
      end
    end

    it 'creates an ApprovalRequest for the decision maker' do
      expect do
        Captain::Assistant::AgentRunnerService.new(
          assistant: assistant, conversation: conversation
        ).generate_response(message_history: [{ role: 'user', content: 'Хочу отменить заказ' }])
      end.to change(Captain::ApprovalRequest, :count).by(1)

      request = Captain::ApprovalRequest.last
      expect(request.conversation).to eq(conversation)
      expect(request.assistant).to eq(assistant)
      expect(request.assignee_id).to eq(decision_maker.id)
      expect(request.assignee_type).to eq('user')
      expect(request.status).to eq('pending')
    end

    it 'notifies the decision maker via ApprovalBot::NotifyJob' do
      Captain::Assistant::AgentRunnerService.new(
        assistant: assistant, conversation: conversation
      ).generate_response(message_history: [{ role: 'user', content: 'Хочу отменить заказ' }])

      expect(ApprovalBot::NotifyJob).to have_received(:perform_later).with(Captain::ApprovalRequest.last)
    end

    it 'includes the REQUIRES_OPERATOR_CLARIFICATION hint in the FAQ result' do
      faq_tool = Captain::Tools::FaqLookupTool.new(assistant)
      tool_ctx = Struct.new(:state).new({})
      result = faq_tool.perform(tool_ctx, query: 'отмена заказа')

      expect(result).to include('[REQUIRES_OPERATOR_CLARIFICATION')
      expect(result).to include('captain--tools--ask_human')
      expect(result).to include('Давай отменим, но прежде уточним причину?')
    end
  end

  # ---------------------------------------------------------------------------
  # Case 2: ask_human sends to a Yclients master (decision makers = yclients staff)
  # ---------------------------------------------------------------------------
  describe 'ask_human with decision maker being a Yclients master' do
    # In this scenario the decision_maker is a regular Chatwoot agent
    # who also happens to be the Yclients staff contact.
    # We mock the Yclients booking client to return masters.

    let(:yclients_hook) do
      create(
        :integrations_hook,
        account: account,
        app_id: 'yclients',
        status: :enabled,
        settings: {
          'partner_token' => 'partner-token',
          'user_token' => 'user-token',
          'company_id' => '101'
        }
      )
    end

    let(:mocked_staff) do
      [
        { 'id' => 10, 'name' => 'Иван Иванов', 'specialization' => 'Мастер маникюра' },
        { 'id' => 11, 'name' => 'Мария Петрова', 'specialization' => 'Мастер педикюра' }
      ]
    end

    let(:mocked_services) do
      [{ 'id' => 1, 'title' => 'Маникюр', 'price_min' => 1500, 'duration' => 60 }]
    end

    let(:booking_client) { instance_double(Crm::Yclients::Api::BookingClient) }

    before do
      yclients_hook # ensure the hook is created

      allow(Crm::Yclients::Api::BookingClient).to receive(:new).and_return(booking_client)
      allow(booking_client).to receive(:get_staff).and_return(mocked_staff)
      allow(booking_client).to receive(:get_services).and_return(mocked_services)
    end

    it 'ask_human sends to configured decision maker (Yclients master)' do
      ask_human_tool = Captain::Tools::AskHumanTool.new(assistant)
      tool_ctx = Struct.new(:state).new({
                                          conversation: {
                                            id: conversation.id,
                                            display_id: conversation.display_id,
                                            additional_attributes: {}
                                          }
                                        })

      expect do
        result = ask_human_tool.perform(
          tool_ctx,
          title: 'Клиент хочет записаться к мастеру. Подтвердите запись.',
          options: ['Подтвердить',  'Предложить другое время']
        )

        expect(result).to include('Approval request #')
        expect(result).to include('Do NOT send any message to the customer')
      end.to change(Captain::ApprovalRequest, :count).by(1)

      request = Captain::ApprovalRequest.last
      expect(request.assignee_id).to eq(decision_maker.id)
      expect(request.assignee_type).to eq('user')
      expect(request.title).to eq('Клиент хочет записаться к мастеру. Подтвердите запись.')
    end

    it 'yclients_get_services returns staff list including mocked masters' do
      services_tool = Captain::Tools::YclientsGetServicesTool.new(assistant)
      tool_ctx = Struct.new(:state).new({
                                          conversation: {
                                            id: conversation.id,
                                            additional_attributes: {}
                                          }
                                        })

      result = services_tool.perform(tool_ctx, company_id: '101')

      expect(result).to include('Иван Иванов')
      expect(result).to include('Мастер маникюра')
      expect(result).to include('Мария Петрова')
      expect(result).to include('Маникюр')
    end

    it 'full flow: captain calls ask_human → creates approval request pointing to decision maker' do
      allow_any_instance_of(Agents::Runner).to receive(:run) do |_runner, _input, **kwargs|
        context = kwargs.fetch(:context)
        ask_human_tool = Captain::Tools::AskHumanTool.new(assistant)
        tool_ctx = Struct.new(:state).new(context[:state])

        ask_human_tool.perform(
          tool_ctx,
          title: 'Выберите мастера для записи клиента',
          options: mocked_staff.map { |s| s['name'] }
        )

        Struct.new(:output, :context).new(
          { 'response' => 'Уточняю с мастером', 'reasoning' => 'yclients master approval' },
          context
        )
      end

      expect do
        Captain::Assistant::AgentRunnerService.new(
          assistant: assistant, conversation: conversation
        ).generate_response(message_history: [{ role: 'user', content: 'Хочу записаться на маникюр' }])
      end.to change(Captain::ApprovalRequest, :count).by(1)

      request = Captain::ApprovalRequest.last
      expect(request.assignee_id).to eq(decision_maker.id)
      expect(request.options.map { |o| o['label'] }).to include('Иван Иванов', 'Мария Петрова')
      expect(ApprovalBot::NotifyJob).to have_received(:perform_later).with(request)
    end
  end

  describe 'decision_maker_ids and Telegram' do
    let(:tool_ctx) do
      Struct.new(:state).new({
                               conversation: {
                                 id: conversation.id,
                                 display_id: conversation.display_id,
                                 additional_attributes: {}
                               }
                             })
    end

    it 'picks the first decision maker in the list who has telegram_chat_id' do
      user_without_tg = create(:user, account: account, telegram_chat_id: nil)
      user_with_tg = create(:user, account: account, telegram_chat_id: '987654321')
      assistant.update!(config: assistant.config.merge('decision_maker_ids' => [user_without_tg.id, user_with_tg.id]))

      ask_human_tool = Captain::Tools::AskHumanTool.new(assistant)
      expect do
        ask_human_tool.perform(tool_ctx, title: 'Need approval')
      end.to change(Captain::ApprovalRequest, :count).by(1)

      expect(Captain::ApprovalRequest.last.assignee_id).to eq(user_with_tg.id)
    end

    it 'returns a clear error when no decision maker has telegram_chat_id' do
      user_without_tg = create(:user, account: account, telegram_chat_id: nil)
      assistant.update!(config: assistant.config.merge('decision_maker_ids' => [user_without_tg.id]))

      ask_human_tool = Captain::Tools::AskHumanTool.new(assistant)
      expect do
        result = ask_human_tool.perform(tool_ctx, title: 'Need approval')
        expect(result).to include('No human decision maker with a configured Telegram account')
      end.not_to change(Captain::ApprovalRequest, :count)
    end

    it 'creates a message with content_type input_select and approval_request_id' do
      ask_human_tool = Captain::Tools::AskHumanTool.new(assistant)
      expect do
        ask_human_tool.perform(tool_ctx, title: 'Need approval')
      end.to change(conversation.messages, :count).by(1)

      message = conversation.messages.last
      expect(message.content_type).to eq('input_select')
      expect(message.content_attributes['approval_request_id']).to eq(Captain::ApprovalRequest.last.id)
      expect(message.content_attributes['items']).not_to be_empty
    end
  end
end
# rubocop:enable RSpec/DescribeClass, RSpec/AnyInstance, RSpec/ExpectInHook
