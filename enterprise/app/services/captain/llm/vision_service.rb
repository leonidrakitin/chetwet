class Captain::Llm::VisionService
  include Integrations::LlmInstrumentation

  def initialize(message_content, assistant_config: {})
    @message_content = message_content
    @assistant_config = assistant_config
  end

  def process
    return @message_content unless images?

    text, image_urls = Captain::OpenAiMessageBuilderService.extract_text_and_attachments(@message_content)

    return use_vision_model(text, image_urls) if requires_vision_extraction?

    @message_content
  end

  private

  def images?
    return false unless @message_content.is_a?(Array)

    @message_content.any? { |part| part.is_a?(Hash) && (part[:type] == 'image_url' || part['type'] == 'image_url') }
  end

  def requires_vision_extraction?
    current_model = @assistant_config&.dig(:llm_model) || 'glm-5'
    %w[glm-4.6 glm-4.6v].exclude?(current_model)
  end

  def use_vision_model(text, image_urls)
    return @message_content if image_urls.blank?

    vision_response = query_vision_model(text, image_urls)
    return @message_content if vision_response.blank?

    enhanced_text = "#{text}\n\n[Image Analysis from Vision Model]\n#{vision_response}"
    [{ type: 'text', text: enhanced_text }]
  end

  def query_vision_model(text, image_urls)
    api_key = system_api_key
    api_base = system_api_base

    return nil if api_key.blank?

    instrument_vision_request do
      Llm::Config.with_api_key(api_key, api_base: api_base) do |context|
        content_parts = [{ type: 'text', text: text || 'Describe this image.' }]
        image_urls.each { |url| content_parts << { type: 'image_url', image_url: { url: url } } }

        chat = context.chat(model: 'glm-4.6v').with_temperature(0.5)
        response = chat.ask(RubyLLM::Content.new(text || 'Describe this image.', image_urls))
        response&.content
      end
    end
  rescue StandardError => e
    Rails.logger.error "[Captain Vision] Error: #{e.message}"
    nil
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
