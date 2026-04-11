class Llm::UsageTrackerService
  include Integrations::LlmUsageDetailsBuilder

  def initialize(account:, feature:, model:, conversation: nil, message: nil, provider: nil) # rubocop:disable Metrics/ParameterLists
    @account = account
    @conversation = conversation
    @message = message
    @feature = feature
    @model = model
    @provider = provider || determine_provider(model)
  end

  def track(usage_data)
    return nil if usage_data.blank?

    usage_details = extract_usage_details(usage_data)
    return nil if usage_details.blank?

    create_usage_record(usage_details)
  rescue StandardError => e
    Rails.logger.error "[LlmUsageTracker] Failed to track usage: #{e.message}"
    ChatwootExceptionTracker.new(e).capture_exception
    nil
  end

  private

  def create_usage_record(usage_details)
    cost_usd = calculate_cost(usage_details)

    LlmUsage.create!(
      account: @account,
      conversation: @conversation,
      message: @message,
      feature: @feature,
      model: @model,
      provider: @provider,
      prompt_tokens: usage_details[:input] || 0,
      completion_tokens: usage_details[:output] || 0,
      total_tokens: usage_details[:total] || 0,
      cache_read_tokens: usage_details[:cache_read_input_tokens],
      cache_creation_tokens: usage_details[:cache_creation_input_tokens],
      cost_usd: cost_usd,
      metadata: build_metadata(usage_details)
    )
  end

  def extract_usage_details(usage_data)
    case usage_data
    when Hash
      usage_details_from_hash(usage_data)
    else
      usage_details_from_message(usage_data, provider: @provider) if usage_data.respond_to?(:input_tokens)
    end
  end

  def calculate_cost(usage_details)
    Llm::CostCalculatorService.calculate(
      model: @model,
      prompt_tokens: usage_details[:input],
      completion_tokens: usage_details[:output]
    )
  end

  def build_metadata(usage_details)
    {
      'credit_multiplier' => credit_multiplier,
      'cache_enabled' => usage_details[:cache_read_input_tokens].present?
    }
  end

  def credit_multiplier
    Llm::Models.models[@model]&.dig('credit_multiplier') || 1
  end

  def determine_provider(model_name)
    return 'openai' if model_name.blank?

    model = model_name.to_s.downcase

    return 'openai' if model.include?('gpt')
    return 'anthropic' if model.include?('claude')
    return 'gemini' if model.include?('gemini') || model.include?('gemma')
    return 'deepseek' if model.include?('deepseek')
    return 'zai' if model.include?('glm')
    return 'qwen' if model.include?('qwen')

    'openai'
  end
end
