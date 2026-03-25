class Captain::Llm::OcrService
  include Integrations::LlmInstrumentation

  def initialize(image_url)
    @image_url = image_url
  end

  # Extracts text from image using GLM-OCR model
  # Useful for scanned documents, screenshots with text
  # Returns extracted text or nil on failure
  def extract_text
    return nil unless @image_url.present?

    instrument_ocr_request do
      response = query_ocr_model
      extract_ocr_result(response)
    end
  rescue StandardError => e
    Rails.logger.error "[Captain OCR] Error: #{e.message}"
    nil
  end

  private

  def query_ocr_model
    api_key = Llm::Config.load_api_key_for_provider('zai')
    endpoint = Llm::Config.load_endpoint_for_provider('zai')

    raise 'Z.AI credentials not configured' if api_key.blank? || endpoint.blank?

    make_ocr_request(api_key, endpoint)
  end

  def make_ocr_request(api_key, endpoint)
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
                                   model: 'glm-ocr',
                                   messages: [{
                                     role: 'user',
                                     content: [
                                       { type: 'text',
                                         text: 'Extract all text from this image. Return only the extracted text without any explanation.' },
                                       { type: 'image_url', image_url: { url: @image_url } }
                                     ]
                                   }],
                                   max_tokens: 2000,
                                   temperature: 0
                                 })

    http.request(request)
  end

  def extract_ocr_result(response)
    return nil unless response.is_a?(Net::HTTPSuccess)

    body = JSON.parse(response.body)
    extracted_text = body.dig('choices', 0, 'message', 'content')

    # Clean up response - OCR might include extra whitespace
    extracted_text&.strip
  rescue StandardError
    nil
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
