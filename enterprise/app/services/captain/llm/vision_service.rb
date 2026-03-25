class Captain::Llm::VisionService
  include Integrations::LlmInstrumentation

  def initialize(message_content, assistant_config: {})
    @message_content = message_content
    @assistant_config = assistant_config
  end

  # Analyzes image(s) in message content using GLM-4.6V or returns as-is for vision-capable models
  # Returns modified message content suitable for vision-capable LLM
  def process
    return @message_content unless has_images?

    text, image_urls = Captain::OpenAiMessageBuilderService.extract_text_and_attachments(@message_content)

    # If we have images and the current model is not vision-capable,
    # use GLM-4.6V to extract and understand the images
    return use_vision_model(text, image_urls) if requires_vision_extraction?

    # Otherwise return as-is (message already has image_url format)
    @message_content
  end

  private

  def has_images?
    return false unless @message_content.is_a?(Array)

    @message_content.any? { |part| part.is_a?(Hash) && (part[:type] == 'image_url' || part['type'] == 'image_url') }
  end

  def requires_vision_extraction?
    current_model = @assistant_config&.dig(:llm_model) || 'glm-5'
    # GLM-5 doesn't support images, need vision model
    !%w[glm-4.6 glm-4.6v].include?(current_model)
  end

  def use_vision_model(text, image_urls)
    return @message_content if image_urls.blank?

    # Build a vision request to GLM-4.6V
    vision_response = query_vision_model(text, image_urls)

    return @message_content if vision_response.blank?

    # Replace original message with vision model's analysis
    enhanced_text = "#{text}\n\n[Image Analysis from Vision Model]\n#{vision_response}"

    [{ type: 'text', text: enhanced_text }]
  end

  def query_vision_model(text, image_urls)
    api_key = Llm::Config.load_api_key_for_provider('zai')
    endpoint = Llm::Config.load_endpoint_for_provider('zai')

    return nil unless api_key.present? && endpoint.present?

    instrument_vision_request do
      response = make_vision_request(api_key, endpoint, text, image_urls)
      extract_vision_response(response)
    end
  rescue StandardError => e
    Rails.logger.error "[Captain Vision] Error: #{e.message}"
    nil
  end

  def make_vision_request(api_key, endpoint, text, image_urls)
    require 'net/http'
    require 'json'

    uri = URI("#{endpoint}/chat/completions")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'

    content_parts = [{ type: 'text', text: text }]
    image_urls.each do |url|
      content_parts << { type: 'image_url', image_url: { url: url } }
    end

    request = Net::HTTP::Post.new(uri.path, {
                                    'Content-Type' => 'application/json',
                                    'Authorization' => "Bearer #{api_key}"
                                  })

    request.body = JSON.generate({
                                   model: 'glm-4.6v',
                                   messages: [{ role: 'user', content: content_parts }],
                                   max_tokens: 500,
                                   temperature: 0.5
                                 })

    http.request(request)
  end

  def extract_vision_response(response)
    return nil unless response.is_a?(Net::HTTPSuccess)

    body = JSON.parse(response.body)
    body.dig('choices', 0, 'message', 'content')
  rescue StandardError
    nil
  end

  def instrument_vision_request
    return yield unless ChatwootApp.otel_enabled?

    tracer.in_span('llm.vision.analysis') do |span|
      span.set_attribute('gen_ai.provider', 'zai')
      span.set_attribute('gen_ai.model', 'glm-4.6v')
      span.set_attribute('gen_ai.operation.name', 'vision_analysis')
      yield
    end
  end
end
