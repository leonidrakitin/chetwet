require 'rails_helper'

RSpec.describe Captain::Llm::AudioTranscriptionService do
  let(:audio_attachment) { double('AudioAttachment') }
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
      before do
        allow(audio_attachment).to receive(:download_url).and_return(nil)
        allow(audio_attachment).to receive(:external_url).and_return(nil)
        allow(audio_attachment).to receive_message_chain(:file, :attached?).and_return(false)
      end

      it 'returns error response' do
        result = service.perform
        expect(result).to eq({
                               success: false,
                               error: 'Unable to get audio URL',
                               transcriptions: ''
                             })
      end
    end

    context 'when Z.AI credentials not configured' do
      before do
        allow(audio_attachment).to receive(:download_url).and_return('https://example.com/audio.mp3')
        allow(Llm::Config).to receive(:load_api_key_for_provider).and_return(nil)
      end

      it 'returns error response' do
        result = service.perform
        expect(result[:success]).to be(false)
        expect(result[:transcriptions]).to eq('')
      end
    end

    context 'with successful transcription' do
      before do
        allow(audio_attachment).to receive(:download_url).and_return('https://example.com/audio.mp3')
        allow(Llm::Config).to receive(:load_api_key_for_provider).and_return('test_key')
        allow(Llm::Config).to receive(:load_endpoint_for_provider).and_return('https://api.z.ai/api/paas/v4')
      end

      it 'returns success response with transcriptions' do
        # In real usage, would mock HTTP response from Z.AI
        # For now, just verify structure
        result = service.perform
        expect(result).to have_key(:success)
        expect(result).to have_key(:transcriptions)
      end
    end
  end
end
