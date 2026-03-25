require 'rails_helper'

RSpec.describe Captain::Llm::AudioTranscriptionService do
  let(:service) { described_class.new(audio_attachment) }

  describe '#perform' do
    context 'when attachment is nil' do
      let(:audio_attachment) { nil }

      it 'returns error response' do
        result = service.perform
        expect(result).to eq({
                               success: false,
                               error: 'No audio attachment',
                               transcriptions: ''
                             })
      end
    end

    context 'when audio URL cannot be retrieved' do
      let(:audio_attachment) { instance_double(Attachment, download_url: nil, external_url: nil) }

      before do
        allow(audio_attachment).to receive_message_chain(:file, :attached?).and_return(false)
      end

      it 'returns error response' do
        result = service.perform
        expect(result[:success]).to be(false)
        expect(result[:error]).to eq('Unable to get audio URL')
      end
    end

    context 'when API key not configured' do
      let(:audio_attachment) { instance_double(Attachment, download_url: 'https://example.com/audio.mp3') }

      it 'returns error response' do
        result = service.perform
        expect(result[:success]).to be(false)
        expect(result[:error]).to eq('Z.AI credentials not configured')
      end
    end
  end
end
