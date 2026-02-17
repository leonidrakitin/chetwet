# frozen_string_literal: true

# Base service for LLM operations using RubyLLM.
# New features should inherit from this class.
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
    Llm::Config.with_api_key(resolve_api_key(model), api_base: resolve_api_base(model)) do |context|
      context.chat(model: model, provider: :openai, assume_model_exists: true).with_temperature(temperature)
    end
  end

  private

  def setup_model
    config_value = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value
    @model = (config_value.presence || DEFAULT_MODEL)
  end

  def setup_temperature
    @temperature = DEFAULT_TEMPERATURE
  end

  def api_key
    @api_key ||= InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
  end

  def api_base
    endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value.presence || 'https://api.openai.com/'
    endpoint = endpoint.chomp('/')
    "#{endpoint}/v1"
  end

  def deepseek_model?(model_name)
    Llm::Models.models.dig(model_name, 'provider') == 'deepseek'
  end

  def qwen_model?(model_name)
    Llm::Models.models.dig(model_name, 'provider') == 'qwen'
  end

  def resolve_api_key(model_name)
    return deepseek_api_key if deepseek_model?(model_name) && deepseek_api_key.present?
    return qwen_api_key if qwen_model?(model_name) && qwen_api_key.present?

    api_key
  end

  def resolve_api_base(model_name)
    return deepseek_api_base if deepseek_model?(model_name) && deepseek_api_key.present?
    return qwen_api_base if qwen_model?(model_name) && qwen_api_key.present?

    api_base
  end

  def deepseek_api_key
    @deepseek_api_key ||= InstallationConfig.find_by(name: 'CAPTAIN_DEEPSEEK_API_KEY')&.value
  end

  def deepseek_api_base
    endpoint = InstallationConfig.find_by(name: 'CAPTAIN_DEEPSEEK_ENDPOINT')&.value.presence || 'https://api.deepseek.com/'
    endpoint = endpoint.chomp('/')
    "#{endpoint}/v1"
  end

  def qwen_api_key
    @qwen_api_key ||= InstallationConfig.find_by(name: 'CAPTAIN_QWEN_API_KEY')&.value
  end

  def qwen_api_base
    endpoint = InstallationConfig.find_by(name: 'CAPTAIN_QWEN_ENDPOINT')&.value.presence || 'https://dashscope.aliyuncs.com/compatible-mode/'
    endpoint = endpoint.chomp('/')
    "#{endpoint}/v1"
  end
end
