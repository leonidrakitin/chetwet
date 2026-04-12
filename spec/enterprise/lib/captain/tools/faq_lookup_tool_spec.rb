require 'rails_helper'

RSpec.describe Captain::Tools::FaqLookupTool, type: :model do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:tool) { described_class.new(assistant) }
  let(:tool_context) { Struct.new(:state).new({}) }

  before do
    create(:installation_config, name: 'CAPTAIN_OPEN_AI_API_KEY', value: 'test-key')

    embedding_service = instance_double(Captain::Llm::EmbeddingService)
    allow(Captain::Llm::EmbeddingService).to receive(:new).and_return(embedding_service)
    allow(embedding_service).to receive(:get_embedding).and_return(Array.new(1024, 0.1))
  end

  describe '#description' do
    it 'returns the correct description' do
      expect(tool.description).to eq('Search FAQ responses using semantic similarity to find relevant answers')
    end
  end

  describe '#parameters' do
    it 'returns the correct parameters' do
      expect(tool.parameters).to have_key(:query)
      expect(tool.parameters[:query].name).to eq(:query)
      expect(tool.parameters[:query].type).to eq('string')
      expect(tool.parameters[:query].description).to eq('The question or topic to search for in the FAQ database')
    end
  end

  describe '#perform' do
    context 'when FAQs exist with high confidence' do
      before do
        mock_search_result = instance_double(Captain::Knowledge::SearchResult)
        allow(mock_search_result).to receive(:confidence).and_return(0.85)
        allow(mock_search_result).to receive(:content).and_return(
          "\nQuestion: How to reset password?\nAnswer: Click on forgot password link\n"
        )
        allow(mock_search_result).to receive(:source_link).and_return(nil)
        allow(mock_search_result).to receive(:requires_operator?).and_return(false)

        search_service = instance_double(Captain::Knowledge::UnifiedSearchService)
        allow(Captain::Knowledge::UnifiedSearchService).to receive(:new).and_return(search_service)
        allow(search_service).to receive(:search).and_return([mock_search_result])
      end

      it 'searches FAQs and returns policy answer with answer_draft' do
        result = tool.perform(tool_context, query: 'password reset')

        expect(result).to be_a(Hash)
        expect(result[:policy]).to eq('answer')
        expect(result[:confidence]).to eq(0.85)
        expect(result[:answer_draft]).to include('Question: How to reset password?')
        expect(result[:answer_draft]).to include('Answer: Click on forgot password link')
      end

      it 'logs tool usage for search' do
        expect(tool).to receive(:log_tool_usage).with('searching', { query: 'password reset' })

        tool.perform(tool_context, query: 'password reset')
      end
    end

    context 'when FAQs exist with source link' do
      before do
        mock_search_result = instance_double(Captain::Knowledge::SearchResult)
        allow(mock_search_result).to receive(:confidence).and_return(0.85)
        allow(mock_search_result).to receive(:content).and_return(
          "\nQuestion: How to reset password?\nAnswer: Click on forgot password link\n"
        )
        allow(mock_search_result).to receive(:source_link).and_return('https://help.example.com/password')
        allow(mock_search_result).to receive(:requires_operator?).and_return(false)

        search_service = instance_double(Captain::Knowledge::UnifiedSearchService)
        allow(Captain::Knowledge::UnifiedSearchService).to receive(:new).and_return(search_service)
        allow(search_service).to receive(:search).and_return([mock_search_result])
      end

      it 'includes source link in sources' do
        result = tool.perform(tool_context, query: 'password')

        expect(result[:sources]).to include('https://help.example.com/password')
      end
    end

    context 'when no FAQs found' do
      before do
        search_service = instance_double(Captain::Knowledge::UnifiedSearchService)
        allow(Captain::Knowledge::UnifiedSearchService).to receive(:new).with(assistant: assistant).and_return(search_service)
        allow(search_service).to receive(:search).with('nonexistent topic').and_return([])
      end

      it 'returns no_match policy' do
        result = tool.perform(tool_context, query: 'nonexistent topic')

        expect(result).to be_a(Hash)
        expect(result[:policy]).to eq('no_match')
        expect(result[:confidence]).to eq(0.0)
        expect(result[:answer_draft]).to be_nil
      end

      it 'logs tool usage for search' do
        expect(tool).to receive(:log_tool_usage).with('searching', { query: 'nonexistent topic' })

        tool.perform(tool_context, query: 'nonexistent topic')
      end
    end

    context 'with blank query' do
      before do
        search_service = instance_double(Captain::Knowledge::UnifiedSearchService)
        allow(Captain::Knowledge::UnifiedSearchService).to receive(:new).with(assistant: assistant).and_return(search_service)
        allow(search_service).to receive(:search).with('').and_return([])
      end

      it 'returns no_match policy' do
        result = tool.perform(tool_context, query: '')

        expect(result[:policy]).to eq('no_match')
      end
    end

    context 'when FAQ requires operator clarification' do
      before do
        mock_search_result = instance_double(Captain::Knowledge::SearchResult)
        allow(mock_search_result).to receive(:confidence).and_return(0.85)
        allow(mock_search_result).to receive(:content).and_return(
          "\nQuestion: How to cancel subscription?\nAnswer: Contact support\n[REQUIRES_OPERATOR_CLARIFICATION]\n"
        )
        allow(mock_search_result).to receive(:source_link).and_return(nil)
        allow(mock_search_result).to receive(:requires_operator?).and_return(true)

        search_service = instance_double(Captain::Knowledge::UnifiedSearchService)
        allow(Captain::Knowledge::UnifiedSearchService).to receive(:new).and_return(search_service)
        allow(search_service).to receive(:search).and_return([mock_search_result])
      end

      it 'returns escalate policy' do
        result = tool.perform(tool_context, query: 'cancel')

        expect(result[:policy]).to eq('escalate')
        expect(result[:requires_operator]).to be true
      end
    end

    context 'when chunk results exist' do
      before do
        mock_search_result = instance_double(Captain::Knowledge::SearchResult)
        allow(mock_search_result).to receive(:confidence).and_return(0.75)
        allow(mock_search_result).to receive(:content).and_return(
          "\nArticle: Pricing\nContext: Pricing page details\nContent: Business plan starts at $19.\n" \
          "Source: https://help.example.com/pricing\n"
        )
        allow(mock_search_result).to receive(:source_link).and_return('https://help.example.com/pricing')
        allow(mock_search_result).to receive(:requires_operator?).and_return(false)

        search_service = instance_double(Captain::Knowledge::UnifiedSearchService)
        allow(Captain::Knowledge::UnifiedSearchService).to receive(:new).and_return(search_service)
        allow(search_service).to receive(:search).and_return([mock_search_result])
      end

      it 'returns chunk content in answer_draft' do
        result = tool.perform(tool_context, query: 'pricing')

        expect(result[:answer_draft]).to include('Article: Pricing')
        expect(result[:answer_draft]).to include('Context: Pricing page details')
        expect(result[:answer_draft]).to include('Content: Business plan starts at $19.')
        expect(result[:sources]).to include('https://help.example.com/pricing')
      end
    end
  end

  describe '#active?' do
    it 'returns true for public tools' do
      expect(tool.active?).to be true
    end
  end
end
