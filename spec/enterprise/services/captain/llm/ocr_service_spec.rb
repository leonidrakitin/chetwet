require 'rails_helper'

RSpec.describe Captain::Llm::OcrService do
  let(:ocr_service) { described_class.new(image_url) }

  describe '#extract_text' do
    context 'with valid image URL but no credentials' do
      let(:image_url) { 'https://example.com/document.png' }

      it 'returns nil when API key not configured' do
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
  end
end
