class Captain::PerformanceMonitoringService
  include Integrations::LlmInstrumentation

  def self.track_assistant_response(assistant_id:, conversation_id:, model:, result:, trace_context: {})
    new(
      assistant_id: assistant_id,
      conversation_id: conversation_id,
      model: model,
      result: result,
      trace_context: trace_context
    ).track
  end

  def initialize(assistant_id:, conversation_id:, model:, result:, trace_context: {})
    @assistant_id = assistant_id
    @conversation_id = conversation_id
    @model = model
    @result = result
    @trace_context = trace_context
  end

  def track
    return unless ChatwootApp.otel_enabled?

    root_span = @trace_context[:root_span]
    return unless root_span

    add_span_attributes(root_span)
  end

  private

  def add_span_attributes(root_span)
    # Model and provider information
    root_span.set_attribute('gen_ai.provider', 'zai')
    root_span.set_attribute('gen_ai.model', @model)

    # Usage metrics
    if @result.respond_to?(:usage)
      root_span.set_attribute('gen_ai.usage.input_tokens', @result.usage.input_tokens.to_i) if @result.usage.input_tokens
      root_span.set_attribute('gen_ai.usage.output_tokens', @result.usage.output_tokens.to_i) if @result.usage.output_tokens
      root_span.set_attribute('gen_ai.usage.cache_read_tokens', @result.usage.cache_read_tokens.to_i) if respond_to_cache_read?(@result)
      root_span.set_attribute('gen_ai.usage.cache_creation_tokens', @result.usage.cache_creation_tokens.to_i) if respond_to_cache_creation?(@result)
    end

    # Z.AI specific metrics
    add_zai_metrics(root_span)

    # Business metrics
    add_business_metrics(root_span)
  end

  def add_zai_metrics(root_span)
    # Reasoning tokens (for Thinking Mode)
    if @result.respond_to?(:reasoning_tokens)
      root_span.set_attribute(
        format(ATTR_LANGFUSE_METADATA, 'reasoning_tokens'),
        @result.reasoning_tokens.to_s
      )
    end

    # Model-specific metadata
    root_span.set_attribute(
      format(ATTR_LANGFUSE_METADATA, 'model_family'),
      model_family(@model)
    )

    root_span.set_attribute(
      format(ATTR_LANGFUSE_METADATA, 'model_tier'),
      model_tier(@model)
    )
  end

  def add_business_metrics(root_span)
    root_span.set_attribute(
      format(ATTR_LANGFUSE_METADATA, 'assistant_id'),
      @assistant_id.to_s
    )

    root_span.set_attribute(
      format(ATTR_LANGFUSE_METADATA, 'conversation_id'),
      @conversation_id.to_s
    )

    # Has reasoning (for tracking Thinking Mode usage)
    has_reasoning = @result.respond_to?(:reasoning) && @result.reasoning.present?
    root_span.set_attribute(
      format(ATTR_LANGFUSE_METADATA, 'has_reasoning'),
      has_reasoning.to_s
    )
  end

  def respond_to_cache_read?(result)
    result.usage.respond_to?(:cache_read_tokens)
  end

  def respond_to_cache_creation?(result)
    result.usage.respond_to?(:cache_creation_tokens)
  end

  def model_family(model)
    case model
    when /^glm-5/
      'glm'
    when /^glm-4/
      'glm'
    when /^glm-ocr/
      'glm-ocr'
    when /^glm-asr/
      'glm-asr'
    else
      'unknown'
    end
  end

  def model_tier(model)
    case model
    when 'glm-5'
      'flagship'
    when /^glm-4\.6/
      'premium'
    when /^glm-4\./
      'standard'
    when /^glm-(ocr|asr)/
      'specialized'
    else
      'unknown'
    end
  end
end
