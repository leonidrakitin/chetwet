require 'rails_helper'

RSpec.describe Captain::Llm::VisionService do
  let(:vision_service) { described_class.new(message_content, assistant_config: config) }
  let(:config) { { llm_model: 'glm-5' } }

  describe '#process' do
    context 'when message has no images' do
      let(:message_content) do
        [{ type: 'text', text: 'Just text' }]
      end

      it 'returns content unchanged' do
        result = vision_service.process
        expect(result).to eq(message_content)
      end
    end

    context 'when message has images with vision-capable model' do
      let(:config) { { llm_model: 'glm-4.6' } }
      let(:message_content) do
        [
          { type: 'text', text: 'Screenshot of error' },
          { type: 'image_url', image_url: { url: 'https://example.com/image.jpg' } }
        ]
      end

      it 'returns content as-is' do
        result = vision_service.process
        expect(result).to eq(message_content)
      end
    end

    context 'with empty content' do
      let(:message_content) { nil }

      it 'returns nil' do
        result = vision_service.process
        expect(result).to be_nil
      end
    end
  end
end
