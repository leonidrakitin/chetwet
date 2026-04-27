module Llm::FallbackExecutor
  class AllProvidersFailedError < StandardError; end

  def self.execute(provider_chain: nil, &)
    chain = provider_chain || Llm::Config.provider_chain
    last_error = nil

    chain.each do |provider_key|
      return Llm::Config.with_provider(provider_key, &)
    rescue RubyLLM::Error, Faraday::Error, StandardError => e
      last_error = e
      Rails.logger.warn("[LLM Fallback] Provider #{provider_key} failed: #{e.class} - #{e.message}")
      next
    end

    raise AllProvidersFailedError, "All providers failed. Last error: #{last_error&.class} - #{last_error&.message}"
  end
end
