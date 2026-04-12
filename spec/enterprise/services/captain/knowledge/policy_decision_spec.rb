require 'rails_helper'

RSpec.describe Captain::Knowledge::PolicyDecision do
  let(:assistant) { create(:captain_assistant) }

  describe '#decide' do
    context 'when no results found' do
      it 'returns no_match policy' do
        decision = described_class.new(assistant: assistant, search_results: [])
        result = decision.decide

        expect(result[:policy]).to eq('no_match')
        expect(result[:confidence]).to eq(0.0)
        expect(result[:answer_draft]).to be_nil
        expect(result[:sources]).to eq([])
      end
    end

    context 'when result requires operator' do
      let(:search_result) { instance_double(Captain::Knowledge::SearchResult) }

      before do
        allow(search_result).to receive(:confidence).and_return(0.85)
        allow(search_result).to receive(:requires_operator?).and_return(true)
        allow(search_result).to receive(:content).and_return('Test content')
        allow(search_result).to receive(:source_link).and_return(nil)
      end

      it 'returns escalate policy' do
        decision = described_class.new(assistant: assistant, search_results: [search_result])
        result = decision.decide

        expect(result[:policy]).to eq('escalate')
        expect(result[:requires_operator]).to be true
      end
    end

    context 'with balanced mode (default)' do
      before do
        allow(assistant).to receive(:knowledge_mode).and_return('balanced')
      end

      context 'when confidence >= 0.55' do
        let(:search_result) { instance_double(Captain::Knowledge::SearchResult) }

        before do
          allow(search_result).to receive(:confidence).and_return(0.60)
          allow(search_result).to receive(:requires_operator?).and_return(false)
          allow(search_result).to receive(:content).and_return('Test answer')
          allow(search_result).to receive(:source_link).and_return('https://example.com')
        end

        it 'returns answer policy' do
          decision = described_class.new(assistant: assistant, search_results: [search_result])
          result = decision.decide

          expect(result[:policy]).to eq('answer')
          expect(result[:confidence]).to eq(0.60)
        end
      end

      context 'when confidence < 0.55' do
        let(:search_result) { instance_double(Captain::Knowledge::SearchResult) }

        before do
          allow(search_result).to receive(:confidence).and_return(0.40)
          allow(search_result).to receive(:requires_operator?).and_return(false)
        end

        it 'returns no_match policy' do
          decision = described_class.new(assistant: assistant, search_results: [search_result])
          result = decision.decide

          expect(result[:policy]).to eq('no_match')
        end
      end
    end

    context 'with strict mode' do
      let(:search_result) { instance_double(Captain::Knowledge::SearchResult) }

      before do
        allow(assistant).to receive(:knowledge_mode).and_return('strict')
        allow(search_result).to receive(:requires_operator?).and_return(false)
        allow(search_result).to receive(:content).and_return('Test answer')
        allow(search_result).to receive(:source_link).and_return(nil)
      end

      context 'when confidence >= 0.70' do
        before do
          allow(search_result).to receive(:confidence).and_return(0.75)
        end

        it 'returns answer policy' do
          decision = described_class.new(assistant: assistant, search_results: [search_result])
          result = decision.decide

          expect(result[:policy]).to eq('answer')
        end
      end

      context 'when confidence < 0.70' do
        before do
          allow(search_result).to receive(:confidence).and_return(0.65)
        end

        it 'returns no_match policy' do
          decision = described_class.new(assistant: assistant, search_results: [search_result])
          result = decision.decide

          expect(result[:policy]).to eq('no_match')
        end
      end
    end

    context 'with ultra_strict mode' do
      let(:search_result) { instance_double(Captain::Knowledge::SearchResult) }

      before do
        allow(assistant).to receive(:knowledge_mode).and_return('ultra_strict')
        allow(search_result).to receive(:requires_operator?).and_return(false)
        allow(search_result).to receive(:content).and_return('Test answer')
        allow(search_result).to receive(:source_link).and_return(nil)
      end

      context 'when confidence >= 0.85' do
        before do
          allow(search_result).to receive(:confidence).and_return(0.90)
        end

        it 'returns answer policy' do
          decision = described_class.new(assistant: assistant, search_results: [search_result])
          result = decision.decide

          expect(result[:policy]).to eq('answer')
        end
      end

      context 'when confidence < 0.85' do
        before do
          allow(search_result).to receive(:confidence).and_return(0.80)
        end

        it 'returns no_match policy' do
          decision = described_class.new(assistant: assistant, search_results: [search_result])
          result = decision.decide

          expect(result[:policy]).to eq('no_match')
        end
      end
    end

    context 'with custom threshold override' do
      let(:search_result) { instance_double(Captain::Knowledge::SearchResult) }

      before do
        allow(assistant).to receive(:knowledge_mode).and_return('balanced')
        allow(assistant).to receive(:knowledge_answer_threshold).and_return(0.90)
        allow(search_result).to receive(:confidence).and_return(0.75)
        allow(search_result).to receive(:requires_operator?).and_return(false)
      end

      it 'uses custom threshold' do
        decision = described_class.new(assistant: assistant, search_results: [search_result])
        result = decision.decide

        expect(result[:policy]).to eq('no_match')
      end
    end
  end
end
