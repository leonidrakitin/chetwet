FactoryBot.define do
  factory :llm_usage do
    account
    conversation { nil }
    message { nil }
    feature { 'assistant' }

    model { 'gpt-4.1-mini' }
    provider { 'openai' }
    prompt_tokens { 100 }
    completion_tokens { 50 }
    total_tokens { 150 }
    cache_read_tokens { nil }
    cache_creation_tokens { nil }
    cost_usd { 0.0001 }
    metadata { {} }
  end
end
