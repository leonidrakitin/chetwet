class Captain::Llm::OcrService
  include Integrations::LlmInstrumentation

  def initialize(image_url)
    @image_url = image_url
  end

  def extract_text
    return nil if @image_url.blank?

    api_key = system_api_key
    return nil if api_key.blank?

    instrument_ocr_request do
      api_base = system_api_base

      Llm::Config.with_api_key(api_key, api_base: api_base) do |context|
        chat = context.chat(model: 'glm-ocr').with_temperature(0)
        prompt = 'Extract all text from this image. Return only the extracted text without any explanation.'
        response = chat.ask(RubyLLM::Content.new(prompt, [@image_url]))
        response&.content&.strip
      end
    end
  rescue StandardError => e
    Rails.logger.error "[Captain OCR] Error: #{e.message}"
    nil
  end

  private

  def system_api_key
    InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
  end

  def system_api_base
    endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value
    return nil if endpoint.blank?

    base = endpoint.to_s.strip.chomp('/')
    %r{/v\d+/?$}.match?(base) ? base : "#{base}/v1"
  end

  def instrument_ocr_request
    return yield unless ChatwootApp.otel_enabled?

    tracer.in_span('llm.ocr.extraction') do |span|
      span.set_attribute('gen_ai.provider', 'zai')
      span.set_attribute('gen_ai.model', 'glm-ocr')
      span.set_attribute('gen_ai.operation.name', 'text_extraction')
      yield
    end
  end
end
