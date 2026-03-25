class Captain::Llm::AudioTranscriptionService
  include Integrations::LlmInstrumentation

  def initialize(audio_attachment)
    @audio_attachment = audio_attachment
  end

  def perform
    return error_response('No audio attachment') if @audio_attachment.blank?

    audio_url = attachment_url
    return error_response('Unable to get audio URL') if audio_url.blank?

    api_key = system_api_key
    return error_response('Z.AI credentials not configured') if api_key.blank?

    instrument_transcription do
      transcribe(api_key, audio_url)
    end
  rescue StandardError => e
    error_response(e.message)
  end

  private

  def attachment_url
    return @audio_attachment.download_url if @audio_attachment.download_url.present?
    return @audio_attachment.external_url if @audio_attachment.external_url.present?

    @audio_attachment.file.attached? ? @audio_attachment.file_url : nil
  end

  def transcribe(api_key, audio_url)
    api_base = system_api_base

    Llm::Config.with_api_key(api_key, api_base: api_base) do |context|
      chat = context.chat(model: 'glm-asr-2512').with_temperature(0)
      prompt = 'Transcribe the audio in this message. Return only the transcribed text.'
      response = chat.ask(RubyLLM::Content.new(prompt, [audio_url]))
      success_response(response&.content)
    end
  rescue StandardError => e
    error_response("Transcription failed: #{e.message}")
  end

  def system_api_key
    InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
  end

  def system_api_base
    endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value
    return nil if endpoint.blank?

    base = endpoint.to_s.strip.chomp('/')
    %r{/v\d+/?$}.match?(base) ? base : "#{base}/v1"
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
