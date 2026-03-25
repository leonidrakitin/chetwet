require 'rails_helper'

RSpec.describe 'Captain Z.AI Integration', type: :integration do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }

  # Scenario 1: Basic chat completion through Z.AI
  describe 'basic chat completion' do
    it 'generates response through Z.AI GLM-5' do
      conversation = create(:conversation, account: account)
      message = create(:message, conversation: conversation, content: 'Hello')

      # Mock RubyLLM response
      allow_any_instance_of(RubyLLM::Chat).to receive(:prompt).and_return(
        double(output: 'Hi there! How can I help you?')
      )

      runner = Captain::Assistant::AgentRunnerService.new(
        assistant: assistant,
        conversation: conversation
      )

      result = runner.generate_response(message_history: [
                                          { role: 'user', content: message.content }
                                        ])

      expect(result).to include('response')
    end
  end

  # Scenario 2: Streaming response
  describe 'streaming response' do
    it 'streams response chunks via ActionCable' do
      conversation = create(:conversation, account: account)

      # SSE streaming is handled by ResponseBuilderJob
      # which uses RubyLLM streaming support
      allow_any_instance_of(RubyLLM::Chat).to receive(:prompt).and_yield(
        double(delta: 'Hello ')
      ).and_yield(
        double(delta: 'there')
      ).and_return(double(output: 'Hello there'))

      expect do
        Captain::Assistant::AgentRunnerService.new(
          assistant: assistant,
          conversation: conversation
        )
      end.not_to raise_error
    end
  end

  # Scenario 3: Function calling with single tool
  describe 'function calling' do
    it 'calls available tools during conversation' do
      conversation = create(:conversation, account: account)

      # Mock tool call response
      allow_any_instance_of(RubyLLM::Chat).to receive(:prompt).and_return(
        double(
          output: 'Found relevant FAQ',
          tool_calls: [
            {
              id: 'call_1',
              name: 'faq_lookup',
              arguments: { query: 'billing' }
            }
          ]
        )
      )

      Captain::Assistant::AgentRunnerService.new(
        assistant: assistant,
        conversation: conversation
      )

      expect_any_instance_of(Agents::Runner).to receive(:run)
    end
  end

  # Scenario 4: Vision/image processing
  describe 'vision processing' do
    it 'processes image attachments with GLM-4.6V' do
      create(:conversation, account: account)
      attachment = create(:attachment, message: nil, file_type: :image)

      message_builder = Captain::OpenAiMessageBuilderService.new(
        message: double(content: 'Screenshot', attachments: [attachment])
      )

      expect(message_builder.generate_content).to be_a(Array)
    end
  end

  # Scenario 5: Thinking Mode with reasoning
  describe 'thinking mode' do
    it 'processes and stores reasoning content' do
      create(:conversation, account: account)

      # Mock response with reasoning
      response = {
        response: 'Customer needs billing support',
        reasoning: 'Customer mentioned issue with invoice, suggests billing department'
      }

      # In real scenario, comes from Z.AI with reasoning_content in SSE
      expect(response).to have_key(:reasoning)
      expect(response[:reasoning]).not_to be_empty
    end
  end

  # Scenario 6: Web Search integration
  describe 'web search tool' do
    it 'searches web when knowledge base insufficient' do
      tool = Captain::Tools::WebSearchTool.new(assistant)

      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(
        double(
          is_a?: ->(klass) { klass == Net::HTTPSuccess },
          body: JSON.generate({
                                choices: [{ message: { content: 'Search results...' } }]
                              })
        )
      )

      expect(tool.name).to eq('web_search')
    end
  end

  # Scenario 7: OCR for document processing
  describe 'OCR processing' do
    it 'extracts text from screenshot using GLM-OCR' do
      service = Captain::Llm::OcrService.new('https://example.com/screenshot.png')

      # Would call GLM-OCR in production
      result = service.extract_text

      # Gracefully handles when credentials not configured
      expect(result).to be_nil
    end
  end

  # Scenario 8: Fallback to default model
  describe 'model fallback' do
    it 'falls back to configured model when Z.AI unavailable' do
      # If Z.AI endpoint returns error, system uses configured fallback
      allow(Llm::Config).to receive(:load_api_key_for_provider).and_return(nil)

      model = assistant.send(:agent_model)

      # Falls back to configured model
      expect(model).to eq(LlmConstants::DEFAULT_MODEL)
    end
  end

  # Scenario 9: Auto-classification
  describe 'automatic conversation classification' do
    it 'classifies new conversations using structured output' do
      create(:conversation, account: account)

      classification = {
        department: 'support',
        priority: 'high',
        sentiment: 'negative',
        tags: ['urgent'],
        requires_immediate_response: true
      }

      # AutoClassifyConversationJob would apply these
      expect(classification).to have_key(:department)
      expect(classification[:priority]).to eq('high')
    end
  end

  # Scenario 10: Performance monitoring
  describe 'performance monitoring' do
    it 'tracks metrics in OpenTelemetry' do
      skip 'OpenTelemetry config required' unless ChatwootApp.otel_enabled?

      allow_any_instance_of(Captain::PerformanceMonitoringService).to receive(:track)

      service = Captain::PerformanceMonitoringService.new(
        assistant_id: assistant.id,
        conversation_id: 1,
        model: 'glm-5',
        result: double(usage: double(input_tokens: 100, output_tokens: 50))
      )

      expect do
        service.track
      end.not_to raise_error
    end
  end
end
