# frozen_string_literal: true

class Llm::BaseAiService
  DEFAULT_MODEL = Llm::Config::DEFAULT_MODEL
  DEFAULT_TEMPERATURE = 1.0

  attr_reader :model, :temperature

  def initialize
    Llm::Config.initialize!
    setup_model
    setup_temperature
  end

  def chat(model: @model, temperature: @temperature)
    provider = Llm::Config.current_provider
    RubyLLM.chat(model: model, provider: provider, assume_model_exists: true).with_temperature(temperature)
  end

  protected

  def track_llm_usage(usage_data, account:, conversation: nil, message: nil, feature: nil)
    return if usage_data.blank?

    Llm::UsageTrackerService.new(
      account: account,
      conversation: conversation,
      message: message,
      feature: feature || feature_name,
      model: @model,
      provider: Llm::Config.current_provider
    ).track(usage_data)
  end

  def feature_name
    'assistant'
  end

  private

  def sanitize_json_response(response)
    return response if response.nil?

    response.strip.sub(/\A```(?:\w*)\s*\n?/, '').sub(/\n?\s*```\s*\z/, '').strip
  end

  def setup_model
    config_value = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value
    @model = (config_value.presence || DEFAULT_MODEL)
  end

  def setup_temperature
    @temperature = DEFAULT_TEMPERATURE
  end
end
