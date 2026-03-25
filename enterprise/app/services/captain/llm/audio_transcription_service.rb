class Captain::Llm::AudioTranscriptionService
  include Integrations::LlmInstrumentation

  def initialize(audio_attachment)
    @audio_attachment = audio_attachment
  end

  # Transcribes audio using GLM-ASR-2512 model
  # Returns hash: { success: true, transcriptions: '...' } or { success: false, error: '...' }
  def perform
    return error_response('No audio attachment') if @audio_attachment.blank?

    audio_url = get_audio_url
    return error_response('Unable to get audio URL') if audio_url.blank?

    instrument_transcription do
      transcribe(audio_url)
    end
  rescue StandardError => e
    error_response(e.message)
  end

  private

  def get_audio_url
    return @audio_attachment.download_url if @audio_attachment.download_url.present?
    return @audio_attachment.external_url if @audio_attachment.external_url.present?

    @audio_attachment.file.attached? ? @audio_attachment.file_url : nil
  end

  def transcribe(audio_url)
    api_key = Llm::Config.load_api_key_for_provider('zai')
    endpoint = Llm::Config.load_endpoint_for_provider('zai')

    return error_response('Z.AI credentials not configured') unless api_key.present? && endpoint.present?

    response = make_transcription_request(api_key, endpoint, audio_url)

    if response.is_a?(Net::HTTPSuccess)
      body = JSON.parse(response.body)
      transcribed_text = body.dig('choices', 0, 'message', 'content')
      success_response(transcribed_text)
    else
      error_response("Transcription failed: #{response.code}")
    end
  end

  def make_transcription_request(api_key, endpoint, audio_url)
    require 'net/http'
    require 'json'

    uri = URI("#{endpoint}/chat/completions")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'

    request = Net::HTTP::Post.new(uri.path, {
                                    'Content-Type' => 'application/json',
                                    'Authorization' => "Bearer #{api_key}"
                                  })

    request.body = JSON.generate({
                                   model: 'glm-asr-2512',
                                   messages: [{
                                     role: 'user',
                                     content: [
                                       { type: 'text', text: 'Transcribe the audio in this message. Return only the transcribed text.' },
                                       { type: 'audio_url', audio_url: { url: audio_url } }
                                     ]
                                   }],
                                   max_tokens: 2000,
                                   temperature: 0
                                 })

    http.request(request)
  end

  def success_response(transcribed_text)
    {
      success: true,
      transcriptions: transcribed_text || ''
    }
  end

  def error_response(error_message)
    {
      success: false,
      error: error_message,
      transcriptions: ''
    }
  end

  def instrument_transcription
    return yield unless ChatwootApp.otel_enabled?

    tracer.in_span('llm.audio.transcription') do |span|
      span.set_attribute('gen_ai.provider', 'zai')
      span.set_attribute('gen_ai.model', 'glm-asr-2512')
      span.set_attribute('gen_ai.operation.name', 'audio_transcription')
      yield
    end
  end
end
