require 'rails_helper'

RSpec.describe Captain::Llm::OcrService do
  let(:ocr_service) { described_class.new(image_url) }

  describe '#extract_text' do
    context 'with valid image URL' do
      let(:image_url) { 'https://example.com/document.png' }

      it 'returns nil when Z.AI credentials not configured' do
        allow(Llm::Config).to receive(:load_api_key_for_provider).and_return(nil)
        result = ocr_service.extract_text
        expect(result).to be_nil
      end
    end

    context 'with empty image URL' do
      let(:image_url) { nil }

      it 'returns nil' do
        result = ocr_service.extract_text
        expect(result).to be_nil
      end
    end

    context 'with error during extraction' do
      let(:image_url) { 'https://example.com/invalid.png' }

      it 'gracefully handles errors' do
        allow(Llm::Config).to receive(:load_api_key_for_provider).and_raise(StandardError, 'Network error')
        result = ocr_service.extract_text
        expect(result).to be_nil
      end
    end
  end
end
