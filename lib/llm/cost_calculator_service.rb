module Llm::CostCalculatorService
  class << self
    def calculate(model:, prompt_tokens:, completion_tokens:, _provider: nil)
      return 0.0 if prompt_tokens.nil? || completion_tokens.nil?

      pricing = pricing_for_model(model)
      return 0.0 if pricing.blank?

      prompt_cost = (prompt_tokens.to_f / 1000) * pricing['prompt'].to_f
      completion_cost = (completion_tokens.to_f / 1000) * pricing['completion'].to_f

      (prompt_cost + completion_cost).round(6)
    end

    def pricing_for_model(model_name)
      return nil if model_name.blank?

      normalized = normalize_model_name(model_name)
      Llm::Models.models[normalized]&.dig('pricing') || Llm::Models.pricing&.dig(normalized)
    end

    private

    def normalize_model_name(model_name)
      model_name.to_s.downcase
    end
  end
end
